# Batch Processing of multiple Sections

Verify that every Species image has a matching ROI archive and Outline, then invoke `process_roi` when all checks pass.

## 1. General Installation

1. **Clone this repository**  
   ```bash
   git clone https://github.com/yourusername/analyze-species.git


2. **Change into the repository folder**

   ```bash
   cd analyze-species
   ```
3. **Add this folder to your MATLAB path**

   ```matlab
   addpath(pwd);
   savepath;
   ```

## 2. Prerequisites

* **MATLAB** R2020a or later
* **ReadImageJROI** toolbox, Version **1.18.0.0** by **Dylan Muir**

  1. Download from MATLAB File Exchange:
     [https://www.mathworks.com/matlabcentral/fileexchange/23700-readimagejroi](https://www.mathworks.com/matlabcentral/fileexchange/23700-readimagejroi)
  2. Install in MATLAB:

     ```matlab
     matlab.addons.install('ReadImageJROI.mltbx');
     ```
  3. Add ReadImageJROI to your MATLAB path (adjust the path to where it installed):

     ```matlab
     addpath(fullfile(userpath,'toolbox','ReadImageJROI-1.18.0.0'));
     savepath;
     ```

## 3. Calling the Function

Once the repository and ReadImageJROI are on your path, simply call:

```matlab
analyze_species(rootFolder)
```

* **rootFolder** : `char` or `string`
  Absolute path to one specimen’s top‐level folder.
  **Example:**

  ```matlab
  analyze_species('C:\Data\Alouatta_seniculus_1170');
  ```

## 4. Folder Structure & Naming Requirements

Your data must follow exactly this layout:

```
rootFolder/
├── Species/
│   └── <rootName>/
│       ├── <rootName>_<ID>.tif
│       ├── <rootName>_<ID2>.tif
│       └── …
├── ROI-files/
│   └── <rootName>_roi/
│       ├── <rootName>_<ID>_roi.zip
│       ├── <rootName>_<ID2>_roi.zip
│       └── …
└── Outlines/
    └── <rootName>_outlined/
        ├── <rootName>_<ID>_outlined.tif
        ├── <rootName>_<ID2>_outlined.tif
        └── …
```

1. **`<rootName>`**

   * Must be identical to the name of `rootFolder`.
   * Example: if `rootFolder` is `Alouatta_seniculus_1170`, then `<rootName>` = `Alouatta_seniculus_1170`.

2. **`<ID>`**

   * A consistent identifier token (e.g. `001`, `002`, … or any fixed string).
   * Must match across Species, ROI-files, and Outlines.

3. **File extensions & suffixes**

   * **Species** images → `*.tif` named `<rootName>_<ID>.tif`
   * **ROI-files** archives → `*.zip` named `<rootName>_<ID>_roi.zip`
   * **Outlines** images → `*.tif` named `<rootName>_<ID>_outlined.tif`

4. **Consistency rules**

   * Folder names and file name prefixes—including underscores—must match exactly.
   * Every Species image ID must have a corresponding ROI archive and Outline image.

---

## 5. (Optional) Batch Processing

To run `analyze_species` on **all** subfolders of a parent directory:

```matlab
parentDir = 'C:\Data';
entries   = dir(parentDir);
for k = 1:numel(entries)
    if entries(k).isdir && ~ismember(entries(k).name, {'.','..'})
        analyze_species(fullfile(parentDir, entries(k).name));
    end
end
```

This loop skips `.` and `..`, then calls the check on each specimen folder automatically.

```
```
