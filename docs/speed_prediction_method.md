# Attention-based Encoder-Decoder for Multi-step Speed Prediction

## Method Section Content (paste into "Method Section Content" box)

### Encoder-Decoder Architecture with Attention

We propose an attention-based encoder-decoder framework for multi-step speed prediction. The architecture consists of three tightly coupled components: (1) an LSTM encoder that summarizes historical driving data, (2) an attention module that dynamically retrieves relevant historical context, and (3) an autoregressive LSTM decoder that fuses multi-source features for step-wise prediction.

**Encoder.** The encoder is a standard LSTM that ingests the historical observation tensor $\mathbf{X} \in \mathbb{R}^{B \times T_h \times D_h}$ (denoted `[B, HIST_SEQ_LEN, HIST_FEAT_DIM]`), where the input at each step is the historical driving features. Internally, the LSTM cell receives the previous cell state $C_{t-1}$ and hidden state $h_{t-1}$, and applies four gating operations — three Sigmoid gates (input, forget, output) and one Tanh gate — combined via element-wise multiplication ($\otimes$) and addition ($\oplus$) to produce the updated cell state $C_t$ and hidden state. The encoder call is:

```
encoder_outputs, hidden, cell = self.encoder(hist_data, debug=debug)
```

This yields: (a) `encoder_outputs` — the full sequence of hidden representations across all historical time steps, shaped `[B, HIST_SEQ_LEN, 2*ENC_HIDDEN_DIM]`; and (b) the final `hidden` and `cell` states shaped `[B, dec_hid_dim]`, which initialize the decoder.

**Attention.** At each decoder time step, the attention module queries the full encoder output sequence with the decoder's last-layer hidden state to compute a context vector:

```
context_vector, attn_weights = self.attention(hidden[-1], encoder_outputs)
```

The context vector selectively retrieves the most informative historical information for the current prediction step. A separate context vector is computed at each decoder step $t, t{+}1, t{+}2, \ldots$

**Decoder.** The decoder is an autoregressive LSTM that generates predictions over $T_p$ future steps. At each step $t$, the decoder receives two external inputs:
- Speed$_t$ — the previously predicted (or ground-truth) speed
- Navigation/environment features$_t$ shaped `[B, PRED_SEQ_LEN, NAV_FEAT_DIM]` — road-level attributes such as gradient, speed limit, and traffic context

These are combined into `dec_input`, concatenated with the attention context vector, and fed into the LSTM:

```
lstm_input = torch.cat((dec_input, context_vector), dim=2)
output, (hidden, cell) = self.lstm(lstm_input, (hidden, cell))
```

The LSTM produces `output` and passes the updated hidden state and cell state to the next time step.

**Three-way Feature Fusion and Prediction.** The final prediction at each step fuses three information sources through concatenation and a fully-connected projection:

```
pred_input = torch.cat((output, context_vector, dec_input), dim=2)
prediction = self.fc_out(pred_input)
```

The three sources are: (1) `output` — the decoder LSTM's current-step output capturing temporal dynamics; (2) `context_vector` — historically relevant information retrieved by attention; (3) `dec_input` — the current external input including navigation and environment data. The FC layer maps the high-dimensional fused representation down to a single scalar, yielding the predicted speed. This process repeats autoregressively: the predicted speed feeds back as input to the next decoder step, producing speed$_{t+1}$, speed$_{t+2}$, speed$_{t+3}$, ...

---

## Figure Caption (paste into "Figure Caption" box)

**Figure 1.** Overview of the proposed attention-based encoder-decoder architecture for multi-step speed prediction. *(Left)* The LSTM encoder processes historical input `[B, HIST_SEQ_LEN, HIST_FEAT_DIM]` through gated operations (Sigmoid ×3, Tanh ×1) with element-wise multiply ($\otimes$) and addition ($\oplus$), producing the full encoder output sequence (`[B, HIST_SEQ_LEN, 2*ENC_HIDDEN_DIM]`) and the final hidden/cell states `[B, dec_hid_dim]`. *(Top)* An attention module queries encoder outputs with the decoder hidden state to compute a context vector at each step, selectively retrieving relevant historical information. *(Right, shaded region)* The autoregressive LSTM decoder generates future speed predictions step by step: at each time step $t$, the decoder concatenates the current speed and navigation/environment features (`[B, PRED_SEQ_LEN, NAV_FEAT_DIM]`) with the context vector as LSTM input, then fuses the LSTM output, context vector, and decoder input via three-way concatenation before a fully-connected layer projects to the predicted speed (high-dimensional to scalar). Hidden states propagate between consecutive LSTM cells to maintain temporal continuity. The diagram should use distinct colored regions for each module (blue/cyan for encoder, yellow/orange for attention, pink/coral for decoder), with icons such as gear for LSTM cells, magnifying glass for attention, speedometer for output, and clock icons for temporal indices. Use gradient-filled arrows with varying thickness to distinguish primary data flow from skip connections, rounded rectangles with soft drop shadows, tensor shape annotations in monospace labels, and a compact legend box.
