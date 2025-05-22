function mask = create_mask(roi)
%CREATE_MASK Generate an empty binary mask matching the corresponding Species image
%
%   mask = create_mask(roi) reads the TIFF image that corresponds to the
%   given ROI struct (annotated with rootPath, rootName, speciesID), obtains
%   its dimensions, and returns a logical mask initialized to false (0)
%   with the same size. You can then fill in the ROI region as needed.
%
%   Syntax
%     mask = create_mask(roi)
%
%   Input Arguments
%     roi : struct  
%           A single ROI struct returned by ReadImageJROI and annotated with:
%             • rootPath   – absolute path to the specimen top‐level folder  
%             • rootName   – name of the specimen folder (e.g. 'Alouatta_seniculus_1170')  
%             • speciesID  – the ID token matching this ROI (e.g. '011')
%
%   Output Arguments
%     mask : logical 2D array  
%            A binary mask of size [height, width] matching the TIFF image,
%            initialized to false so that all pixels are zero.
%
%   Example
%     % Suppose roi.rootPath = 'D:\Data\Alouatta_seniculus_1170'
%     % roi.rootName = 'Alouatta_seniculus_1170'
%     % roi.speciesID = '011'
%     mask = create_mask(roi);
%     % mask is a [H×W] logical array of false values.
%
%   Requirements
%     Folder structure under roi.rootPath must be:
%       roi.rootPath/
%       └── Species/
%           └── roi.rootName/
%               └── roi.rootName_roi.speciesID.tif
%
%   See also ReadImageJROI, imread

    %% Build full path to the matching Species TIFF image
    % The image lives in:
    %   <rootPath>/Species/<rootName>/<rootName>_<speciesID>.tif
    imageName = sprintf('%s_%s.tif', roi.rootName, roi.speciesID);
    imagePath = fullfile(...
        roi.rootPath, ...        % top-level folder
        'Species', ...           % Species subfolder
        roi.rootName, ...        % folder named after the specimen
        imageName ...            % the TIFF filename
    );

    %% Read the image to determine its dimensions
    try
        img = imread(imagePath);  % read the TIFF file into an array
    catch ME
        % If reading fails, abort with an error
        error('create_mask:ImageReadFailed', ...
              'Could not read image "%s": %s', imagePath, ME.message);
    end

    %% Initialize a logical mask of zeros with same height & width
    [height, width, ~] = size(img);  % ignore color channels if present
    mask = false(height, width);     % create a logical array of all false
end
