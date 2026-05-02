# EEM Fluorescence Data Processing and Modeling Pipeline for Food Adulteration Detection

---

## Method Section Content

### Data Processing and Modeling Pipeline

The overall methodology follows an eleven-step pipeline that spans from raw spectral acquisition to model interpretation, as illustrated in the figure.

**Data Acquisition and Preprocessing (Steps 1--4).** The pipeline begins with the raw EEM fluorescence spectral data. In Step 1, the raw data files are parsed and loaded into structured matrices. Step 2 computes the average pure-water blank matrix from replicate blank measurements, which serves as the baseline reference. Step 3 performs Raman scattering subtraction by removing the pure-water blank from each sample spectrum, eliminating the first-order Raman band that would otherwise interfere with fluorescence signals. Step 4 addresses Rayleigh scattering artifacts — both first-order and second-order — by masking or interpolating the diagonal regions in the EEM where excitation light directly leaks into the emission channel.

**Chemometric Decomposition (Step 5).** Following scattering correction, Parallel Factor Analysis (PARAFAC) is applied to decompose the three-way EEM tensor into chemically meaningful fluorescent components. Each component corresponds to a unique excitation-emission profile representing a distinct fluorophore or chemical species in the sample, providing spectroscopic interpretability complementary to the data-driven CNN approach.

**Quality Control and Visualization (Step 6).** The preprocessed EEM spectra are visualized as contour or surface plots for quality inspection, ensuring that scattering artifacts have been adequately removed and that fluorescence features are clearly resolved before model training.

**Dataset Construction and Splitting (Step 7).** The cleaned EEM matrices are organized into a labeled dataset with corresponding adulteration levels. The dataset is split into training, validation, and test subsets using a stratified sampling strategy to ensure balanced class representation across all partitions.

**Parallel Model Construction (Steps 8a--8b).** Two classification models are constructed in parallel: (a) a CNN model (Step 8a) that directly ingests the two-dimensional EEM matrix as image-like input and learns hierarchical spatial-spectral features through convolutional layers; and (b) an SVM baseline model (Step 8b) that operates on vectorized or PARAFAC-derived features, serving as a conventional chemometric benchmark for performance comparison.

**Training, Evaluation, and Comparison (Steps 9--10).** Both models are trained and evaluated using consistent cross-validation protocols and performance metrics (Step 9). Step 10 provides a systematic comparison of classification performance through confusion matrices, ROC curves, and accuracy metrics, quantifying the advantage of the deep learning approach over the traditional SVM baseline.

**Interpretability Analysis (Step 11).** Finally, Grad-CAM activation maps generated from the CNN are jointly analyzed with the PARAFAC-decomposed fluorescent components (Step 11). This combined interpretation links the CNN's learned discriminative regions in the EEM space to chemically identifiable fluorophores, bridging the gap between data-driven prediction and spectroscopic domain knowledge.

---

## Figure Caption

**Figure X.** Flowchart of the complete EEM fluorescence data processing and modeling pipeline for food adulteration detection. The pipeline proceeds from raw EEM spectral data through sequential preprocessing steps: data parsing and loading (Step 1), pure-water blank averaging (Step 2), Raman scattering subtraction (Step 3), and Rayleigh scattering correction (Step 4). A branching path leads to PARAFAC fluorescent component decomposition (Step 5) for chemometric analysis. After EEM visualization and quality inspection (Step 6), the dataset is constructed and partitioned (Step 7). Two parallel modeling tracks are pursued: a CNN-based classifier (Step 8a) and an SVM baseline model (Step 8b). Both converge at model training and evaluation (Step 9), followed by comparative performance visualization (Step 10). The pipeline concludes with joint Grad-CAM and PARAFAC interpretation (Step 11), linking CNN-learned discriminative EEM regions to chemically meaningful fluorescent components. The diagram should use a vertical top-to-bottom flow with rounded rectangles for each step, diamond-shaped decision/branch nodes where the pipeline diverges (Steps 4→5 and 7→8a/8b) and converges (8a/8b→9), light purple/lavender fill for step boxes, dark borders, and clear directional arrows. All text labels inside the figure must be in Chinese.
