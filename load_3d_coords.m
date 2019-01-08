function obj = load_3d_coords(fname)

fileID = fopen(fname);
text = textscan(fileID, '%s', 'delimiter', newline);
text = text{1};

% set up field types
v = [];
f.v = [];

for line_num = 1 : length(text)
	line = text{line_num};
	
	switch line(1:2)
		case 'v '
			v = [v; sscanf(line(3:end),'%f')'];
		case 'f '
			fv = zeros(1,3);
			str = textscan(line(2:end),'%s'); % break into strings separated by spaces. str is a cell array now.
			str = str{1};
			
			for i = 1 : length(str)
				vertex_string = str{i};
				vertex_coords = textscan(vertex_string, '%s', 'delimiter', '/');
				vertex_coords = str2double(vertex_coords{1}{1});
				fv(1, i) = vertex_coords;
			end
			f.v = [f.v; fv];
			% extract the fisrt number cooresponding to a vertex number
% 			tok = strtok(str,'/');
% 			for k = 1:length(tok)
% 				fv(k) = str2double(tok{k});
% 			end
% 			f.v = [f.v; fv];
	end
end

% % parse .obj file
% while 1
% 	tline = fgetl(fid);
% 	if ~ischar(tline),   break,   end  % exit at end of file
% 	ln = sscanf(tline,'%s',1); % line type
% 	%disp(ln)
% 	switch ln
% 		case 'v'   % mesh vertexs
% 			v = [v; sscanf(tline(2:end),'%f')'];
% 		case 'f'   % face definition
% 			fv = zeros(3,1);
% 			str = textscan(tline(2:end),'%s'); % break into strings separated by spaces. str is a cell array now.
% 			str = str{1};
% 			
% 			% extract the fisrt number cooresponding to a vertex number
% 			tok = strtok(str,'/');
% 			for k = 1:length(tok)
% 				fv(k) = str2double(tok{k});
% 			end
% 			f.v = [f.v; fv];
% 	end
% end
fclose(fileID);

% set up matlab object
obj.v = v; obj.f = f;

end

