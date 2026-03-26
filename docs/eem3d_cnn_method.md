# CNN-based Classification of EEM-3D Fluorescence Data for Food Adulteration Detection

---

## Method Section Content

### Convolutional Neural Network Architecture for EEM-3D Classification

We propose a lightweight convolutional neural network (CNN) for classifying excitation-emission matrix (EEM) three-dimensional fluorescence spectra to detect and quantify food adulteration. The network takes as input the EEM-3D fluorescence map of size $91 \times 95$ pixels, corresponding to the excitation and emission wavelength dimensions, with adulteration levels ranging from 0% to 50%.

**Feature Extraction Backbone.** The backbone consists of four sequential convolutional blocks, each comprising a $3 \times 3$ convolution, batch normalization (BN), and ReLU activation. The first block expands the input to 16 feature maps with spatial dimensions $45 \times 47$, followed by $2 \times 2$ max pooling. The second block increases the channel depth to 32 with output size $22 \times 23$, again followed by $2 \times 2$ max pooling. The third block further doubles the channels to 128 at spatial resolution $11 \times 11$, followed by $2 \times 2$ max pooling. The fourth and final convolutional block maintains 128 channels at $11 \times 11$ spatial resolution with no pooling applied, preserving spatial detail for downstream interpretability analysis via Gradient-weighted Class Activation Mapping (Grad-CAM).

**Classification Head.** After the final convolutional block, a global average pooling (GAP) layer aggregates each feature map into a single scalar, producing a 128-dimensional feature vector. This vector is passed through a fully connected (FC) layer that maps to the output logits. The network supports two classification modes: (1) binary classification (adulterated vs. non-adulterated, 2 classes) and (2) multi-class classification (7 adulteration levels).

**Interpretability.** The deliberate omission of pooling after the last convolutional layer preserves the $11 \times 11$ spatial resolution, enabling Grad-CAM to generate high-fidelity activation heatmaps that highlight the excitation-emission wavelength regions most discriminative for adulteration detection.

---

## Figure Caption

**Figure X.** Architecture of the proposed CNN for EEM-3D fluorescence-based food adulteration classification. The input is a $91 \times 95$ EEM-3D fluorescence map with adulteration levels spanning 0--50%. The network comprises four convolutional blocks (Conv $3 \times 3$ + BN + ReLU), progressively increasing channel depth from 16 to 32, 128, and 128, with $2 \times 2$ max pooling applied after the first three blocks to reduce spatial dimensions from $45 \times 47$ to $22 \times 23$ and $11 \times 11$. The final block omits pooling to preserve spatial resolution for Grad-CAM interpretability analysis. A global average pooling (GAP) layer aggregates the 128 feature maps into a compact vector, which is projected by a fully connected (FC) layer to either 2 outputs (binary: adulterated vs. non-adulterated) or 7 outputs (multi-class adulteration level). The diagram should use a blue-to-red heatmap style for the EEM-3D input, warm orange/coral tones for convolutional feature maps with increasing depth depicted by block thickness, a distinct green block for GAP, and a purple block for the FC output. Spatial dimension and channel annotations should appear adjacent to each block. Use clean horizontal arrows for data flow, consistent drop shadows, and a sans-serif font for all labels.
