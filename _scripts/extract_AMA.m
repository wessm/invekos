clear all; close all;

%  create separate shapefiles with AMA Nutzungsart-Classes

%% Dirs (trailing '/' !!)

home = '/home/mischa/';




out_dir = 'Projects/invekos/2017/improved_groups/';

improved_shp = 'invekos_schlaege_polygon_improved.shp';

base_dir = 'Projects/Productivity/MISCHA/';

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

[~, layer, ~] = fileparts([home, out_dir, improved_shp]);



%% loop through unique list and extract


for c = 1:numel(AMA_h)
    
    AMA_h{c}
    
    %  make directory
    dirname = [out_dir, 'AMA_Nutzungsarten/'];
    
    if exist([home, dirname], 'dir') ~= 7
        mkdir([home, dirname]);
    end
    
    out = [dirname, 'invekos2017_', AMA_h{c}, '.shp']; 
    
    %  subset shape
    if exist([home, out(1:end-4), '.zip'], 'file') ~= 2
        system(['docker run ', ...
            '-v ', home, ':/data --rm -it ', ...
            gdal, ' ogr2ogr ', ...
            '-f "ESRI Shapefile" ', ...
            '-dialect SQLite ', ...
            '-sql "SELECT * FROM ', layer, ' WHERE ', AMA_h{c}, ' = 1" ', ...
            out, ' ', ...
            out_dir, improved_shp]);
    end
    
    %  compress and delete originals
    files = struct2cell(dir([home, dirname, 'invekos2017_', AMA_h{c}, '.*']));
    if exist([home, out(1:end-4), '.zip'], 'file') ~= 2
        zip([home, out(1:end-4)], cellfun(@(x) [home, dirname, x], files(1,:), 'uni', false));
    end

    cellfun(@(x) delete([home, dirname, x]), files(1,:));



end

%%  create README file

% read links to google drive from file

fid = fopen([home, dirname, 'google-drive-links.txt']);
GD_links = {};
tline = fgetl(fid);
while ischar(tline)
    GD_links = [GD_links, {tline}];
    tline = fgetl(fid);
end

fclose(fid);





fid=fopen([home, dirname, 'README.md'],'w');
fprintf(fid, '# INVEKOS 2017 separate files for AMA Nutzungsart Groups\n\n\n');

fprintf(fid, 'for the AMA Codes, see [here](https://www.ama.at/getattachment/f3e9b8ab-8533-49f2-8c97-0daf45b06751/Nutzungsarten_Codes_Varianten.pdf)\n\n');

for l = 1:numel(AMA_h)
    fprintf(fid, ['* [', AMA_h{l}, '](', GD_links{l}, ')\n\n']);
end
fclose(fid);







