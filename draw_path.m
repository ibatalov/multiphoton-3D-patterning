function [image, path] = draw_path(path, varargin)

fill = false;
image_size = [1024, 1024];
fill_color = 1;
close_path = true;

if ~isempty(varargin)
	range = [-1, 1; -1, 1];
	for i = 1 : length(varargin)/2
		switch varargin{2*i-1}
			case 'pixelsize'
				image_size = varargin{2*i};
			case 'range'
				range = varargin{2*i};
			case 'fill'
				fill = varargin{2*i};
			case 'fill_color'
				fill_color = varargin{2*i};
			case 'close_path'
				close_path = varargin{2*i};
		end
	end
	% converting path coords into image coords
	path = [(path(:,1) - range(1,1))*(image_size(1)-1)/(range(1,2) - range(1,1)) + 1, (path(:,2) - range(2,1))*(image_size(2)-1)/(range(2,2) - range(2,1)) + 1];
end


lines = zeros(image_size);
dots = zeros(image_size);
dots(round(path(1,1)), round(path(1,2))) = 1;
if close_path
	start = path(end, 1:2);
	start_index = 1;
else
	start = path(1, 1:2);
	start_index = 2;
end

for i = start_index : size(path, 1)
	finish = path(i,1:2);
	a = finish - start;
	dist = (a(1)^2 + a(2)^2)^0.5;
	if dist > 0
		a = a / dist;
	end
	
	for j = 0 : dist
		lines(round(start(1) + j*a(1)), round(start(2) + j*a(2))) = 1;
	end
	
	dots(round(finish(1)), round(finish(2))) = 1;
	start = finish;
end

if fill
	inner_px = get_closed_shape_inner_pixels(lines);
	lines(inner_px) = fill_color;
end

image = zeros([image_size, 3]);
image(:,:,2) = lines;
image(:,:,3) = dots;

end

