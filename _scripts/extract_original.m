clear all; close all;

%  extract separate shapefiles and class lists from original INVEKOS
%  Shapefile

%% Dirs (trailing '/' !!)

home = '/home/mischa/';



out_dir = 'Projects/invekos/2017/original/';

base_dir = 'Projects/Productivity/MISCHA/';
invekos_shp = 'INVEKOS/invekos_schlaege_polygon.shp'; %  in base dir!


crop_list_file = 'list_crop_types.csv';


addpath([home, base_dir, 'func/']);
set_env_vars();
gdal = getenv('DOCKER_GDAL');



%% extract from polygon

[~, layer, ~] = fileparts([home, base_dir, invekos_shp]);

if (exist([home, out_dir, 'list_crops_per_polygon.csv'], 'file') ~= 2 || ...
        exist([home, out_dir, 'list_ID_per_polygon.csv'], 'file') ~= 2)
    
     
    %  extract crop list
    system(['docker run ', ...
        '-v ', home, ':/data --rm -it ', ...
        gdal, ' ogr2ogr ', ...
        '-f "CSV" ', ...
        '-dialect SQLite ', ...
        '-sql "SELECT SNAR_BEZEI FROM ', layer, '" ', ...
        out_dir, 'list_crops_per_polygon.csv', ' ', ...
        base_dir, invekos_shp]);
    
    %  remove quotes and re-write
    D = importdata([home, out_dir, 'list_crops_per_polygon.csv'], '\t');
    D = strrep(D(:), '"', '');
    
    filePh = fopen([home, out_dir, 'list_crops_per_polygon.csv'],'w');
    fprintf(filePh,'%s\n',D{:});
    fclose(filePh);
    
    %  extract IDs
    system(['docker run ', ...
        '-v ', home, ':/data --rm -it ', ...
        gdal, ' ogr2ogr ', ...
        '-f "CSV" ', ...
        '-dialect SQLite ', ...
        '-sql "SELECT ID FROM ', layer, '" ', ...
        out_dir, 'list_ID_per_polygon.csv', ' ', ...
        base_dir, invekos_shp]);
else 
    D = importdata([home, out_dir, 'list_crops_per_polygon.csv'], '\t');
end
    
D(1) = [];
ID = importdata([home, out_dir, 'list_ID_per_polygon.csv'], '\t');
ID = ID.data;





%%  reformat and save unique list

if exist([home, out_dir, crop_list_file], 'file') ~= 2


    list_crop = unique(D);
    
    %  remove umlaute
    list_crop = strrep(list_crop, 'Ö', 'OE');
    list_crop = strrep(list_crop, 'Ü', 'UE');
    list_crop = strrep(list_crop, 'Ä', 'AE');
    
    list_crop = sort(list_crop);
    

    filePh = fopen([home, out_dir, crop_list_file],'w');
    fprintf(filePh,'%s\n',list_crop{:});
    fclose(filePh);
    

else
    list_crop = importdata([home, out_dir, crop_list_file]);
end


%% loop through unique list and extract

for l = 1:numel(list_crop)
    

    
    %  for lookup
    crop_lookup = list_crop{l}
    crop_lookup = strrep(crop_lookup, 'OE', 'Ö');
    crop_lookup = strrep(crop_lookup, 'UE', 'Ü');
    crop_lookup = strrep(crop_lookup, 'AE', 'Ä');
    
    %  remove invalid characters
    crop = list_crop{l};
    crop = strrep(crop, '/', '-');
    crop = strrep(crop, ' ', '_');
    crop = strrep(crop, '(', '');
    crop = strrep(crop, ')', '');
    crop = strrep(crop, ':', '');

    
    %  make directory
    dirname = [out_dir, 'separate/'];
    
    if exist([home, dirname], 'dir') ~= 7
        mkdir([home, dirname]);
    end
    
    out = [dirname, 'invekos2017_', crop, '.shp']; 
    
    %  subset shape
    if exist([home, out(1:end-4), '.zip'], 'file') ~= 2
        system(['docker run ', ...
            '-v ', home, ':/data --rm -it ', ...
            gdal, ' ogr2ogr ', ...
            '-f "ESRI Shapefile" ', ...
            '-dialect SQLite ', ...
            '-sql "SELECT * FROM ', layer, ' WHERE SNAR_BEZEI LIKE ''%', crop_lookup, '%''" ', ...
            out, ' ', ...
            base_dir, invekos_shp]);
    end
    
    %  compress and delete originals
    files = struct2cell(dir([home, dirname, 'invekos2017_', crop, '.*']));
    if exist([home, out(1:end-4), '.zip'], 'file') ~= 2
        zip([home, out(1:end-4)], cellfun(@(x) [home, dirname, x], files(1,:), 'uni', false));
    end

    cellfun(@(x) delete([home, dirname, x]), files(1,:));
    
end


%% create README

fid=fopen([home, dirname, 'README.md'],'w');
fprintf(fid, '# INVEKOS 2017 separate files for each "Nutzungsart" from AMA\n\n\n');
for l = 1:numel(list_crop)
    
    
    crop = list_crop{l};
    crop = strrep(crop, '/', '-');
    crop = strrep(crop, ' ', '_');
    crop = strrep(crop, '(', '');
    crop = strrep(crop, ')', '');
    crop = strrep(crop, ':', '');
    
    
    fprintf(fid, ['* [', list_crop{l}, '](https://homepage.boku.ac.at/mwess/2017/original/separate/', crop, '.zip)\n\n']);
end
fclose(fid);
    
    



