clear all; close all;

%  create shapefile with improved classification


%% Dirs (trailing '/' !!)

home = '/home/mischa/';



out_dir = 'Projects/invekos/2017/improved_groups/';

base_dir = 'Projects/Productivity/MISCHA/';
invekos_shp = 'INVEKOS/invekos_schlaege_polygon.shp'; %  in base dir!


new_shp = 'invekos_schlaege_polygon_improved.shp'; %  input file must be copied there


classification_file = 'classification.csv';


addpath([home, base_dir, 'func/']);
set_env_vars();
gdal = getenv('DOCKER_GDAL');

%%  load classification data

CL = importdata([home, out_dir, classification_file]);

headers = CL.textdata(1,2:end);
headers = strrep(headers, '"', '');

orig_cl = CL.textdata(2:end, 1);

orig_cl_id = CL.textdata(2:end, 2);

AMA_h = headers(1, 4:end);
AMA = CL.data(:, 2:end);

AMA(isnan(AMA)) = 0;

new_cl = CL.textdata(2:end, 3);
new_cl_id = CL.data(:, 1);



%% loop through classes

[~, layer, ~] = fileparts([home, out_dir, new_shp]);



%  build sql query
all = {'G0_ID INTEGER(3)', 'G1 CHARACTER', 'G1_ID INTEGER(2)'};


for c = 1:numel(AMA_h)
    all = [all, [AMA_h{c}, ' INTEGER(1)']];
end

%% add fields to table

for c = 1:numel(all)

    %  extract crop list
    system(['docker run ', ...
        '-v ', home, ':/data --rm -it ', ...
       gdal, ' ogrinfo ', ...
       '-sql "ALTER TABLE ', layer, ' ADD ', all{c}, '" ', ...
        out_dir, new_shp]);
end

%% populate fields

for i = 1:numel(orig_cl)
    
    
    %  build query
    query = ['"UPDATE ', layer, ' SET '];
    %  put umlate back for lookup
    orig_group = orig_cl{i};
    
    orig_group_lookup = strrep(orig_group, 'OE', 'Ö');
    orig_group_lookup = strrep(orig_group_lookup, 'UE', 'Ü');
    orig_group_lookup = strrep(orig_group_lookup, 'AE', 'Ä');
    
    orig_id = num2str(orig_cl_id{i});
    new_group = new_cl{i};
    new_id = num2str(new_cl_id(i));
    query = [query, 'SNAR_BEZEI = ''', orig_group, ''', G0_ID = ', orig_id, ', G1 = ''', new_group, ''', ', ...
        'G1_ID = ', new_id, ', '];
    for c = 1:numel(AMA_h)
        query = [query, AMA_h{c}, ' = ', num2str(AMA(i,c)), ', '];
    end
    
    query = [query(1:end-2), ' WHERE SNAR_BEZEI LIKE ''%', orig_group_lookup, '%''"'];
    
    %  extract crop list
    system(['docker run ', ...
        '-v ', home, ':/data --rm -it ', ...
       gdal, ' ogrinfo ', ...
       '-dialect SQLite ', ...
       '-sql ', query, ' ', ...
        out_dir, new_shp]);



end


%% loop through unique list and extract

for l = 1:numel(unique(new_cl_id))
    

    
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
    
    %  create TIF
    %if exist([home, out(1:end-4), '.tif'], 'file') ~= 2
    %    system(['docker run ', ...
    %        '-v ', home, ':/data --rm -it ', ...
    %        gdal, ' gdal_rasterize ', ...
    %        '-a ID ', ...
    %        '-l ', layer, ' ', ...
    %        '-tr 10 10 ', ...
    %        '-sql "SELECT * FROM ', layer, ' WHERE SNAR_BEZEI LIKE ''%', crop_lookup, '%''" ', ...
    %        '-init 0 ', ...
    %        base_dir, invekos_shp, ' ', ...
    %        out(1:end-4), '.tif']);
    %end


end










