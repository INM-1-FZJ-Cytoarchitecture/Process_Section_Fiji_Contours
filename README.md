# Analyze Species Toolbox

A MATLAB suite of functions to verify folder structure and file naming for specimen images, read ImageJ ROI files, and generate a labeled tissue mask for gray matter, white matter, and cerebellum.

---

## 1. Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/analyze-species.git
   cd analyze-species
   ```
2. **Add to MATLAB path**

   ```matlab
   addpath(pwd);  % current folder
   savepath;
   ```

## 2. Prerequisites

* **MATLAB** R2020a or later
* **ReadImageJROI** (v1.18.0.0) by Dylan Muir

  1. Download from MATLAB File Exchange:
     [https://www.mathworks.com/matlabcentral/fileexchange/23700-readimagejroi](https://www.mathworks.com/matlabcentral/fileexchange/23700-readimagejroi)
  2. Install in MATLAB:

     ```matlab
     matlab.addons.install('ReadImageJROI.mltbx');
     addpath(fullfile(userpath,'toolbox','ReadImageJROI-1.18.0.0'));
     savepath;
     ```

## 3. Folder Structure & File Naming

All specimen data lives under a single folder named after the **Specimen ID**. For example:

```
Alouatta_seniculus_1170/    ← Specimen folder (Specimen ID)
├── Species/
│   └── Alouatta_seniculus_1170/
│       └── Alouatta_seniculus_1170_<ImageID>.tif
├── ROI-files/
│   └── Alouatta_seniculus_1170_roi/
│       └── Alouatta_seniculus_1170_<ImageID>_roi.zip
└── Outlines/
    └── Alouatta_seniculus_1170_outlined/
        └── Alouatta_seniculus_1170_<ImageID>_outlined.tif
```

* **Specimen ID** (`Alouatta_seniculus_1170`) is both the top‐level folder name and the prefix for all files and subfolders.
* **ImageID** is always a three‐digit number (e.g. `001`, `011`, `123`).
* File extensions:

  * Species & Outlines images → `.tif`
  * ROI archives            → `.zip`

**Key points:**

1. The three‐digit ImageID links each Species image to its ROI and Outline files.
2. Folder and file names must match exactly, including underscores and hyphens.

## 4. ROI Naming & Suffix Rules.

Each ROI name (field `strName` in the struct) must end with one of the following suffixes:

| Suffix | Tissue       | Code in mask |
| ------ | ------------ | ------------ |
| `#g`   | Gray matter  | 1            |
| `#i`   | Inner gray   | 1            |
| `#w`   | White matter | 2            |
| `#c`   | Cerebellum   | 3            |
| `#o`   | Outer only   | 0 (cleared)  |

* **Priority**: gray (#g,#i) → white (#w) → cerebellum (#c) → outer (#o) clears all.
* **Overlaps**: ROIs may overlap. The final mask code follows the above fill order and outer-only regions reset to 0.

### Examples of ROI and Species Images

Below are sample images demonstrating correct naming conventions. Place these files in the same folder as this README:

![ROI Example](example1.png)

*`example1.png`: Screenshot of an ROI file named `Alouatta_seniculus_1170_011_roi.zip` showing contours with suffixes.*

![Species Example](example2.png)

*`example2.png`: Example mask image named `Alouatta_seniculus_1170_011_mask.tif` in the mask folder (created by the script within specimen folder).*

## 5. Usage. Usage

1. **Check a single specimen**

   ```matlab
   analyze_species(rootFolder);
   ```

   * Verifies folder structure and matching Species⇄ROI⇄Outline files.
   * Prints summary and warnings.
   * Calls `process_roi` if all checks pass.

2. **Process ROIs & generate mask**

   ```matlab
   % After analyze_species has passed
   results = process_roi(roiPaths, speciesIDs);
   % roiPaths: cell array of full .zip paths
   % speciesIDs: matching ID tokens

   % To obtain mask for a set:
   mask = create_mask(rois);
   imshow(mask, []);
   ```

3. **Batch processing**

   ```matlab
   parentDir = 'C:\Data';
   entries = dir(parentDir);
   for k = 1:numel(entries)
       name = entries(k).name;
       if entries(k).isdir && ~ismember(name,{'.','..'})
           analyze_species(fullfile(parentDir,name));
       end
   end
   ```

## 6. Function Reference

* **`analyze_species(rootFolder)`**

  * Checks required subfolders (`Species`, `ROI-files`, `Outlines`).
  * Verifies matching file counts and IDs.
  * Prints summary and warnings.
  * Calls `process_roi` for ROI processing.

* **`process_roi(roiPaths, speciesIDs)`**

  * Reads each ROI ZIP via `ReadImageJROI`.
  * Annotates ROI structs with paths and IDs.
  * Lists contour names in Command Window.
  * Calls `create_mask` for each set and computes areas via `calculate_areas`.

* **`create_mask(rois)`**

  * Builds an empty mask of the correct image size.
  * Fills regions according to ROI suffix rules.
  * Returns a uint8 mask with tissue codes.

---
