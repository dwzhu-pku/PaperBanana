#!/usr/bin/env python3
"""
AI生成图像文字纠错工具。

流程：macOS Vision OCR（逐字定位） → LLM校对 → 标注 + 可选遮盖
遮盖方案：1px padding + 亮像素中位数背景色填充

Usage:
    python scripts/fix_text.py image.png
    python scripts/fix_text.py image.png --mask
    python scripts/fix_text.py image.png --model openai/gpt-oss-20b
"""

import argparse
import json
import re
import sys
from datetime import datetime
from difflib import SequenceMatcher
from pathlib import Path

import sys
import numpy as np
from openai import OpenAI
from PIL import Image, ImageDraw

try:
    import Foundation
    import Vision
    from Quartz import CIImage
except ModuleNotFoundError:
    if sys.platform != "darwin":
        print("Error: fix_text.py requires macOS (Vision framework). Not supported on this platform.")
        sys.exit(1)
    raise


# --- Config ---

LM_STUDIO_BASE = "http://localhost:1234/v1"
DEFAULT_MODEL = "openai/gpt-oss-20b"
MASK_PADDING = 1       # px, Vision bbox 外扩
BG_SAMPLE_MARGIN = 15  # px, 背景色采样范围


# --- Helpers ---

def _parse_response(raw: str) -> dict | list | None:
    raw = re.sub(r"<think>.*?</think>", "", raw, flags=re.DOTALL).strip()
    m = re.search(r"```(?:json)?\s*(\{.*?\}|\[.*?\])\s*```", raw, re.DOTALL)
    if m:
        raw = m.group(1)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        print(f"[WARN] 模型返回非JSON:\n{raw[:300]}")
        return None


def _text_similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, a, b).ratio()


# --- Step 1: macOS Vision OCR ---

def vision_ocr(img_path: str) -> list[dict]:
    """macOS Vision 文字识别，返回行级+逐字 bbox。"""
    img = Image.open(img_path)
    img_w, img_h = img.size

    url = Foundation.NSURL.fileURLWithPath_(str(img_path))
    ci_image = CIImage.imageWithContentsOfURL_(url)
    if ci_image is None:
        print(f"[ERROR] Vision 无法加载图像: {img_path}")
        return []

    img.close()

    request = Vision.VNRecognizeTextRequest.alloc().init()
    request.setRecognitionLanguages_(["zh-Hans", "en"])
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    request.setUsesLanguageCorrection_(False)

    handler = Vision.VNImageRequestHandler.alloc().initWithCIImage_options_(ci_image, None)
    success, error = handler.performRequests_error_([request], None)
    if not success:
        print(f"[ERROR] Vision OCR 失败: {error}")
        return []

    if not request.results():
        return []

    results = []
    for obs in request.results():
        candidates = obs.topCandidates_(1)
        if not candidates:
            continue
        candidate = candidates[0]
        text = candidate.string()
        conf = obs.confidence()

        box = obs.boundingBox()
        lx1 = int(box.origin.x * img_w)
        ly1 = int((1 - box.origin.y - box.size.height) * img_h)
        lx2 = int((box.origin.x + box.size.width) * img_w)
        ly2 = int((1 - box.origin.y) * img_h)

        char_bboxes = []
        for i, ch in enumerate(text):
            char_range = Foundation.NSRange(i, 1)
            box_obs, _ = candidate.boundingBoxForRange_error_(char_range, None)
            if box_obs:
                b = box_obs.boundingBox()
                cx1 = int(b.origin.x * img_w)
                cy1 = int((1 - b.origin.y - b.size.height) * img_h)
                cx2 = int((b.origin.x + b.size.width) * img_w)
                cy2 = int((1 - b.origin.y) * img_h)
                char_bboxes.append({"char": ch, "bbox": [cx1, cy1, cx2, cy2]})

        results.append({
            "text": text,
            "bbox": [lx1, ly1, lx2, ly2],
            "confidence": conf,
            "chars": char_bboxes,
        })

    return results


# --- Step 2: LLM 校对 ---

def proofread(ocr_results: list[dict], client: OpenAI, model: str, reference: str | None = None) -> list[dict] | None:
    seen = set()
    unique = []
    for ocr in ocr_results:
        if ocr["text"] not in seen:
            seen.add(ocr["text"])
            unique.append(ocr)

    text_lines = [f"{i+1}. {ocr['text']}" for i, ocr in enumerate(unique)]
    ocr_block = "\n".join(text_lines)

    prompt = f"""以下是AI生成的学术图表中OCR识别出的文字（已去重）。请检查错别字（如形近字"力"→"热"）。

重要：
- 这是图表，相同文字在不同位置重复出现是正常的，不是错误
- 文字重复、语句不通顺可能是OCR识别问题，不一定是图中的错字
- 只报告你非常确信是形近字替换、笔画错误等真正错别字的情况

{ocr_block}

返回JSON: {{"errors": [{{"index": 序号, "wrong": "错误文字", "correct": "修正后", "note": "说明"}}]}}
没有错误返回: {{"errors": []}}"""
    if reference:
        prompt += f"\n参考: {reference}"

    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
            max_tokens=2048,
        )
        raw = (resp.choices[0].message.content or "").strip()
    except Exception as e:
        print(f"[ERROR] LLM 请求失败: {e}")
        return None  # None = failure, [] = no errors

    if not raw:
        print("[WARN] LLM 返回空内容")
        return None

    result = _parse_response(raw)
    if not isinstance(result, dict):
        return None

    errors = result.get("errors") or []
    if not isinstance(errors, list):
        return None

    normalized = []
    for e in errors:
        if not isinstance(e, dict):
            continue
        wrong = e.get("wrong", "")
        correct = e.get("correct", "")
        if wrong and wrong != correct:
            normalized.append({"wrong": wrong, "correct": correct, "note": e.get("note", "")})
    return normalized


# --- Step 3: 匹配错误到逐字 bbox ---

def match_errors(errors: list[dict], ocr_results: list[dict]) -> list[dict]:
    matched = []

    for err in errors:
        wrong = err["wrong"]
        best_ocr = None
        best_score = 0.0

        for ocr in ocr_results:
            ocr_text = ocr["text"]
            if wrong in ocr_text:
                score = 0.95
            elif ocr_text in wrong:
                score = 0.85
            else:
                score = _text_similarity(wrong, ocr_text)
            if score > best_score:
                best_score = score
                best_ocr = ocr

        if not best_ocr or best_score < 0.3:
            print(f"    [WARN] 未匹配:「{wrong}」")
            continue

        ocr_text = best_ocr["text"]
        chars = best_ocr.get("chars", [])

        if wrong == ocr_text:
            char_bboxes = [c["bbox"] for c in chars]
        elif wrong in ocr_text and chars:
            start_idx = ocr_text.index(wrong)
            end_idx = start_idx + len(wrong)
            char_bboxes = [chars[i]["bbox"] for i in range(start_idx, end_idx) if i < len(chars)]
        else:
            char_bboxes = [best_ocr["bbox"]]

        matched.append({
            **err,
            "line_bbox": best_ocr["bbox"],
            "char_bboxes": char_bboxes,
            "ocr_text": ocr_text,
        })
        print(f"    匹配: 「{wrong}」 ↔ OCR「{ocr_text}」 ({len(char_bboxes)} 字符)")

    return matched


# --- Step 4: 标注 ---

def annotate_image(img: Image.Image, matched: list[dict]) -> Image.Image:
    result = img.copy().convert("RGB")
    draw = ImageDraw.Draw(result)

    for i, item in enumerate(matched):
        x1, y1, x2, y2 = item["line_bbox"]
        for offset in range(2):
            draw.rectangle([x1 - offset, y1 - offset, x2 + offset, y2 + offset], outline=(255, 0, 0))
        label = f"{i+1}"
        lx, ly = max(0, x1 - 1), max(0, y1 - 20)
        draw.rectangle([lx, ly, lx + 14 * len(label), ly + 18], fill=(255, 0, 0))
        draw.text((lx + 2, ly), label, fill=(255, 255, 255))

    return result


# --- Step 5: 像素级遮盖 ---

def _sample_bg_color(img_arr: np.ndarray, x1: int, y1: int, x2: int, y2: int) -> np.ndarray:
    """从 bbox 周围采样亮像素中位数作为背景色。"""
    img_h, img_w = img_arr.shape[:2]
    mx1 = max(0, x1 - BG_SAMPLE_MARGIN)
    my1 = max(0, y1 - BG_SAMPLE_MARGIN)
    mx2 = min(img_w, x2 + BG_SAMPLE_MARGIN)
    my2 = min(img_h, y2 + BG_SAMPLE_MARGIN)

    region = img_arr[my1:my2, mx1:mx2]
    if region.size == 0:
        return np.array([255, 255, 255], dtype=np.uint8)

    gray = np.mean(region, axis=2)
    threshold = np.percentile(gray, 75)
    bg_pixels = region[gray >= threshold]

    if len(bg_pixels) > 0:
        return np.median(bg_pixels, axis=0).astype(np.uint8)
    return np.array([255, 255, 255], dtype=np.uint8)


def mask_errors(img: Image.Image, matched: list[dict]) -> Image.Image:
    """逐字遮盖：1px padding + 亮像素中位数背景色填充。"""
    img_arr = np.array(img.convert("RGB")).copy()
    img_h, img_w = img_arr.shape[:2]

    for item in matched:
        for cb in item["char_bboxes"]:
            x1, y1, x2, y2 = cb
            x1 = max(0, x1 - MASK_PADDING)
            y1 = max(0, y1 - MASK_PADDING)
            x2 = min(img_w, x2 + MASK_PADDING)
            y2 = min(img_h, y2 + MASK_PADDING)

            if x2 <= x1 or y2 <= y1:
                continue

            bg = _sample_bg_color(img_arr, x1, y1, x2, y2)
            img_arr[y1:y2, x1:x2] = bg

        print(f"  遮盖: 「{item['wrong']}」→「{item['correct']}」 ({len(item['char_bboxes'])} 字符)")

    return Image.fromarray(img_arr)


# --- Step 6: 报告 ---

def generate_report(img_path, img_size, errors, matched, model):
    lines = [
        f"# 文字校对报告",
        f"",
        f"- **图像**: {img_path.name} ({img_size[0]}x{img_size[1]})",
        f"- **日期**: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"- **模型**: {model}",
        f"- **检测到错误**: {len(errors)} 处",
        f"",
    ]

    if matched:
        lines.append("## 错误列表\n")
        lines.append("| # | 错误文字 | 修正为 | 说明 |")
        lines.append("|---|----------|--------|------|")
        for i, m in enumerate(matched):
            lines.append(f"| {i+1} | {m['wrong']} | {m['correct']} | {m.get('note','')} |")
        lines.append("")

    return "\n".join(lines)


# --- Main ---

def main():
    parser = argparse.ArgumentParser(description="AI生成图像文字纠错")
    parser.add_argument("image", help="输入图像路径")
    parser.add_argument("-r", "--reference", help="参考文本")
    parser.add_argument("-o", "--output", help="输出路径前缀")
    parser.add_argument("--mask", action="store_true", help="启用遮盖模式")
    parser.add_argument("--api-base", default=LM_STUDIO_BASE)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    args = parser.parse_args()

    img_path = Path(args.image)
    if not img_path.exists():
        print(f"错误: 找不到 {img_path}")
        sys.exit(1)

    try:
        img = Image.open(img_path)
    except Exception as e:
        print(f"错误: 无法打开图像 {img_path}: {e}")
        sys.exit(1)
    print(f"图像: {img_path.name} ({img.size[0]}x{img.size[1]})")
    print(f"模型: {args.model}\n")

    # Step 1
    print("  [1/3] macOS Vision OCR...")
    ocr_results = vision_ocr(str(img_path))
    if not ocr_results:
        print("\n  OCR 未检测到任何文字，退出。")
        sys.exit(1)
    print(f"         检测到 {len(ocr_results)} 个文字区域")

    # Step 2
    client = OpenAI(base_url=args.api_base, api_key="not-needed")
    print("  [2/3] LLM 校对中...")
    errors = proofread(ocr_results, client, args.model, args.reference)

    if errors is None:
        print("\n  校对失败，请检查 LLM 服务是否正常。")
        sys.exit(1)
    if not errors:
        print("\n  未发现错误。")
        return

    print(f"\n  发现 {len(errors)} 处错误:")
    for i, err in enumerate(errors):
        print(f"    [{i+1}] 「{err['wrong']}」→「{err['correct']}」  {err.get('note','')}")

    # Step 3
    print("\n  [3/3] 匹配到逐字位置...")
    matched = match_errors(errors, ocr_results)

    if not matched:
        print("  无法定位。")
        return

    # 输出
    out_prefix = args.output or str(img_path.parent / img_path.stem)

    annotated = annotate_image(img, matched)
    ann_path = out_prefix + "_annotated.png"
    annotated.save(ann_path)
    print(f"\n  标注图: {ann_path}")

    if args.mask:
        masked = mask_errors(img, matched)
        mask_path = out_prefix + "_masked.png"
        masked.save(mask_path)
        print(f"  遮盖图: {mask_path}")

    report = generate_report(img_path, img.size, errors, matched, args.model)
    report_path = out_prefix + "_report.md"
    Path(report_path).write_text(report, encoding="utf-8")
    print(f"  报告: {report_path}")

    print("\n完成!")


if __name__ == "__main__":
    main()
