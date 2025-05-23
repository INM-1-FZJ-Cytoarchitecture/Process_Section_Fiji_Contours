# Analyze Species Toolbox

A MATLAB suite for:  
- Verifying folder structure and file naming for specimen images  
- Reading ImageJ ROI files  
- Generating labeled tissue masks and computing tissue‐area metrics  

---

## 1. Installation

1. **Clone the repository**  
   ```bash
   git clone https://github.com/yourusername/analyze-species.git
   cd analyze-species
   ````

2. **Add to MATLAB path**

   ```matlab
   addpath(pwd);   % add this folder
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

All data for one specimen resides in a single folder named with the **Specimen ID** (e.g. `Alouatta_seniculus_1170`):

```
Alouatta_seniculus_1170/                 ← Specimen folder (Specimen ID)
├── Species/
│   └── Alouatta_seniculus_1170/
│       └── Alouatta_seniculus_1170_<ImageID>.tif
├── ROI-files/
│   └── Alouatta_seniculus_1170_roi/
│       └── Alouatta_seniculus_1170_<ImageID>_roi.zip
├── Outlines/
│   └── Alouatta_seniculus_1170_outlined/
│       └── Alouatta_seniculus_1170_<ImageID>_outlined.tif
└── masks/                               ← created by `create_mask`
    └── Alouatta_seniculus_1170_<ImageID>_mask.tif
```

* **Specimen ID** = folder name, and prefix for all subfolders/files.
* **ImageID** = three‐digit number (e.g. `001`, `011`, `123`).
* File extensions:

  * Species & Outlines → `.tif`
  * ROI archives     → `.zip`
  * Masks            → `.tif`

**Key points:**

1. Folder and file names must match exactly, including underscores and hyphens.
2. ImageID links Species → ROI → Outline → Mask.

## 4. ROI Naming & Suffix Rules

Each ROI’s `strName` must end with one of these suffixes:

| Suffix | Tissue                  | Mask Code |
| :----: | :---------------------- | :-------- |
|  `#g`  | Neocortical GM          | 1         |
|  `#i`  | Inner gray matter       | 1         |
|  `#a`  | Archicortical GM        | 4         |
|  `#w`  | White matter            | 2         |
|  `#c`  | Cerebellum              | 3         |
|  `#o`  | Outer only (non-tissue) | 0         |

* **Fill order**:

  1. Neocortical GM (`#g`, `#i`)
  2. Archicortical GM (`#a`)
  3. White matter (`#w`)
  4. Cerebellum (`#c`)
  5. Outer only (`#o`) — overrides all to code 0

* ROIs may overlap; outer‐only regions reset any underlying tissue code to 0.

### Examples

![ROI naming example](example1.png)
*`example1.png`: ROI contours in `Alouatta_seniculus_1170_011_roi.zip`*

![Species image example](example2.png)
*`example2.png`: Species image `Alouatta_seniculus_1170_011.tif`*

## 5. Usage

1. **Check folder integrity**

   ```matlab
   analyze_species(rootFolder)
   ```

   * Verifies subfolders `Species`, `ROI-files`, `Outlines`
   * Checks matching IDs across `.tif` and `.zip` files
   * Prints summary and warnings
   * Calls `process_roi` if all checks pass

2. **Process ROIs & compute areas**

   ```matlab
   results = process_roi(roiPaths, speciesIDs, debug_mode)
   ```

   * **roiPaths**: cell array of ROI ZIP file paths
   * **speciesIDs**: cell array of three-digit IDs
   * **debug\_mode** (optional, default `false`): toggle verbose output
   * **results**: table with columns

     * `rootName`, `rootPath`, `filePath`, `speciesPath`, `maskPath`
     * `ImageID`, `numROIs`, `NeocorticalGM`, `White`, `Cerebellum`, `ArchicorticalGM`

3. **Batch processing**

   ```matlab
   parentDir = 'C:\Data';
   folders   = dir(parentDir);
   for k = 1:numel(folders)
     name = folders(k).name;
     if folders(k).isdir && ~ismember(name, {'.','..'})
       analyze_species(fullfile(parentDir, name));
     end
   end
   ```

## 6. Function Reference

* **`analyze_species(rootFolder)`**
  Verifies folder structure and matching file IDs, then calls `process_roi`.

* **`process_roi(roiPaths, speciesIDs, debug_mode)`**
  Extracts ImageIDs, reads ROI ZIPs, builds masks via `create_mask`, computes tissue areas via `calculate_areas`, and returns a fixed‐schema table.

* **`create_mask(rois)`**
  Builds and saves a labeled mask TIFF from ROI structs.

* **`calculate_areas(mask)`**
  Counts pixels of each tissue code (1,2,3,4) and returns a one-row table with variables
  `NeocorticalGM`, `White`, `Cerebellum`, `ArchicorticalGM`.

---
