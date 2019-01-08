function [image_rgb] = visualize_pairs(pairs, varargin)

image_size = [1024, 1024];

if ~isempty(varargin)
	range = [-1, 1; -1, 1];
	for i = 1 : length(varargin)/2
		switch varargin{2*i-1}
			case 'pixelsize'
				image_size = varargin{2*i};
			case 'range'
				range = varargin{2*i};
		end
	end
	% converting path coords into image coords
	pairs = [(pairs(:,1) - range(1,1))*(image_size(1)-1)/(range(1,2) - range(1,1)) + 1, (pairs(:,2) - range(2,1))*(image_size(2)-1)/(range(2,2) - range(2,1)) + 1];
end

image_hsv = zeros([image_size, 3]);
for i = 1 : size(pairs, 1)/2
	start = pairs(i*2-1, 1:2);
	finish = pairs(i*2,1:2);
	a = finish - start;
	dist = (a(1)^2 + a(2)^2)^0.5;
	if dist > 0
		a = a / dist;
	end

	hue = rand();
	sat = rand();
	density_factor = 1;
	for j = 0 : density_factor*dist
		image_hsv(round(start(1) + j*a(1)/density_factor), round(start(2) + j*a(2)/density_factor), 1) = hue;
		image_hsv(round(start(1) + j*a(1)/density_factor), round(start(2) + j*a(2)/density_factor), 2) = sat;
		image_hsv(round(start(1) + j*a(1)/density_factor), round(start(2) + j*a(2)/density_factor), 3) = 1;
	end
end
image_rgb = hsv2rgb(image_hsv);

end