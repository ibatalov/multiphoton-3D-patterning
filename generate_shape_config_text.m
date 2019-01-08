function [text] = generate_shape_config_text(template, varargin)
%%
% template - cells array of strings, each cell represents one line of the
% template
% Name, Value pairs:
% Name | string/number
% ID | string/number
% SHAPE | number (8 - polygon, 5 - square)
% LASERPOWER | number
% X | x-coordinates (column vector)
% Y | y-coordinates (column vector)

%%
name = [];
id = [];
shape = [];
laserpower = [];
x = [];
y = [];

for i = 1 : length(varargin)/2
	switch varargin{2*i-1}
		case 'Name'
			name = varargin{2*i};
		case 'ID'
			id = varargin{2*i};
		case 'SHAPE'
			shape = varargin{2*i};
		case 'LASERPOWER'
			laserpower = varargin{2*i};
		case 'X'
			x = varargin{2*i};
		case 'Y'
			y = varargin{2*i};
	end
end

text = [];

for j = 1 : length(template)
	str = template{j};
	if ~isempty(name)
		% check if it's a name line
		startIndex = regexp(str,'Name="[0-9A-z_-]+"', 'once');
		if ~isempty(startIndex) && startIndex == 1
			str = ['Name="', num2str(name), '"'];
		end
	end
	if ~isempty(id)
		% check if it's a name line
		startIndex = regexp(str,'ID="[0-9A-z]+"', 'once');
		if ~isempty(startIndex) && startIndex == 1
			str = ['ID="', num2str(id), '"']; % in case I am dumb enough to provide the ID as a number rather than a string
		end
	end
	if ~isempty(shape)
		% check if it's a shape line
		startIndex = regexp(str,'SHAPE=[0-9]+', 'once');
		if ~isempty(startIndex) && startIndex == 1
			str = ['SHAPE=', num2str(shape)];
		end
	end
	if ~isempty(laserpower)
		% setting laser power
		startIndex = regexp(str,'LASERPOWER=[0-9]+', 'once');
		if ~isempty(startIndex) && startIndex == 1
			str = ['LASERPOWER=', num2str(laserpower)];
		end
	end
	if ~isempty(x)
		startIndex = regexp(str,'X=.+', 'once');
		if ~isempty(startIndex) && startIndex == 1
			str = sprintf('X=%i', round(x(1)));
			for point_num = 2 : size(x, 1)
				str = sprintf([str, ',%i'], round(x(point_num)));
			end
		end
	end
	if ~isempty(y)
		startIndex = regexp(str,'Y=.+');
		if ~isempty(startIndex) && startIndex == 1
			str = sprintf('Y=%i', round(y(1)));
			for point_num = 2 : size(y, 1)
				str = sprintf([str, ',%i'], round(y(point_num)));
			end
		end
	end
	text = [text, str, '\r\n'];
end

end

