function mask = create_mask(roi, thisPath)
%CREATE_MASK Generate an empty binary mask matching the corresponding Species image
%
%   mask = create_mask(roi, thisPath) determines the top-level specimen folder
%   from the full path to an ROI ZIP file (thisPath), reads the matching TIFF
%   image in the Species subfolder to obtain its dimensions, and returns a
%   logical mask initialized to false (0) of the same size.
%
%   Syntax
%     mask = create_mask(roi, thisPath)
%
%   Input Arguments
%     roi       : struct
%                 A single ROI struct returned by ReadImageJROI. Must have
%                 field `strName` containing the ID token (e.g. '011').
%     thisPath  : char or string
%                 Absolute path to the ROI ZIP file from which `roi` was read.
%                 Example:
%                   'D:\…\Alouatta_seniculus_1170\ROI-files\Alouatta_seniculus_1170_roi\Alouatta_seniculus_1170_011_roi.zip'
%
%   Output Arguments
%     mask      : logical 2D array
%                 A binary mask of zeros with the same height and width as
%                 the matching Species TIFF image.
%
%   Example
%     % Given thisPath and roi.strName = '011':
%     mask = create_mask(roi, ...
%       'D:\Data\Alouatta_seniculus_1170\ROI-files\Alouatta_seniculus_1170_roi\Alouatta_seniculus_1170_011_roi.zip');
%     % mask is a [H×W] logical array of false values.
%
%   Requirements
%     - Folder structure under the specimen top folder must be:
%         rootFolder/
%         └── Species/
%             └── <rootName>/
%                 └── <rootName>_<ID>.tif
%       where <rootName> matches the name of rootFolder, and <ID> = roi.strName.

    %% Derive rootFolder from thisPath
    % thisPath = .../ROI-files/<rootName>_roi/<filename>.zip
    zipFolder    = fileparts(thisPath);        % .../ROI-files/<rootName>_roi
    parentFolder = fileparts(zipFolder);       % .../ROI-files
    rootFolder   = fileparts(parentFolder);    % .../<rootName>

    %% Extract rootName (species folder name)
    [~, rootName] = fileparts(rootFolder);     % e.g. 'Alouatta_seniculus_1170'

    %% Build path to the matching Species image
    % Filename: <rootName>_<ID>.tif
    imageName = sprintf('%s_%s.tif', rootName, roi.strName);
    imagePath = fullfile(rootFolder, 'Species', rootName, imageName);

    %% Read image to get dimensions
    try
        img = imread(imagePath);               % Read the TIFF image
    catch ME
        error('create_mask:ImageReadFailed', ...
              'Could not read image "%s": %s', imagePath, ME.message);
    end

    %% Initialize empty mask
    % Determine image size: height × width (ignore color channels)
    [height, width, ~] = size(img);
    mask = false(height, width);             % Logical array of zeros
end
