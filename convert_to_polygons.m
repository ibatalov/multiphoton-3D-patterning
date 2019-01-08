function [polygons, colors] = convert_to_polygons(pairs, varargin)

pairs = pairs(:,1:2);

if ~isempty(varargin)
	image_size = [1024, 1024];
	range = [-1, 1; -1, 1]*1.5;
	for i = 1 : length(varargin)/2
		switch varargin{2*i-1}
			case 'pixelsize'
				image_size = varargin{2*i};
			case 'range'
				range = varargin{2*i};
			case 'fill'
				fill = varargin{2*i};
		end
	end
end

%threshold = 0.000001;
threshold = min(0.0005, min(sum((pairs(1:2:end,:) - pairs(2:2:end,:)).^2, 2).^0.5)/50);
fprintf('polygon matching threshold: %d\n', threshold);

polygons = {};
polygon_inner_px = {}; % contains inner pixels that are not a part of any smaller object
polygon_border_px = {};
polygon_inner_areas = [];
border_image = zeros(image_size);
%range = [min(pairs(:,1)), max(pairs(:,1)); min(pairs(:,2)), max(pairs(:,2))];
%range = range * 1.1;

unfinished_poly_image = zeros([image_size, 3]);

while ~isempty(pairs)
	open_polygons = {};
	open_polygons{1} = [pairs(1, :); pairs(2, :)]; % add first point
	closed_polygons = {};
	pairs_to_remove = [1]; % contains indices of pairs to be removed. To convert them to the actual indices, multiply by 2 (and subtract one for the second member of a pair)
	
	while ~isempty(open_polygons)
		polygons_to_remove = [];
		for poly_n = 1 : length(open_polygons)
			polygon = open_polygons{poly_n};
			last_point = polygon(end, :);
			
			% since there is some error in calculating point coordinates,
			% can't use '==' to find matches
			match_array = (sum((pairs - last_point).^2, 2)).^0.5 < threshold;
			matched_indices = find(match_array);
			next_point_indices = matched_indices + (mod(matched_indices, 2) - 0.5)*2;
			new_pairs_to_remove = floor((matched_indices - 1)/2) + 1;
			pairs_to_remove = unique([pairs_to_remove; new_pairs_to_remove(:)]);
			
			%fprintf('1. number of next points: %i\n', length(next_point_indices));
			path_completed = false;
			
			if ~isempty(next_point_indices)
				% check if there is a direct connection to the initial point
				%fprintf('polygon size: %i\n', size(polygon, 1));
				match_array = sum((pairs(next_point_indices, :) - polygon(1,:)).^2, 2) < threshold*threshold;
				if size(polygon, 1) > 2 && max(match_array) == 1
					closed_polygons{end+1} = polygon;
					path_completed = true;
					%fprintf('New closed polygon of length %i. total: %i temp polygons\n', size(polygon, 1), size(closed_polygons, 2));
				end
				
				% remove indices that are already in the path
				points_to_remove = [];
				for i = 1 : numel(next_point_indices)
					match_array = sum((polygon - pairs(next_point_indices(i),:)).^2, 2) < threshold*threshold;
					if ~isempty(find(match_array,1))
						points_to_remove = [points_to_remove; i];
					end
				end
				if ~isempty(points_to_remove)
					next_point_indices(points_to_remove) = [];
					%fprintf('2. number of next points: %i\n', length(next_point_indices));
				end
			end
			
			if numel(next_point_indices) > 1
				% path is branching, add new paths into the open polygons' pool
				for i = 2 : numel(next_point_indices)
					open_polygons{end+1} = [open_polygons{poly_n}; pairs(next_point_indices(i), :)];
				end
				%fprintf('branching! New %i paths. Total: %i open paths\n', numel(next_point_indices) - 1, length(open_polygons));
			end
			
			if numel(next_point_indices) > 0
				open_polygons{poly_n} = [open_polygons{poly_n}; pairs(next_point_indices(1), :)];
			else
				% remove the polygon since there are no new neighbors
				polygons_to_remove = [polygons_to_remove; poly_n];
				%fprintf('removing path of length %i\n', size(open_polygons{poly_n}, 1));
				if ~path_completed
					temp_hsv = rgb2hsv(draw_path(polygon, 'pixelsize', image_size, 'range', range, 'fill', false, 'close_path', false));
					temp_hsv(:,:,1) = (temp_hsv(:,:,1) > 0)*rand();
					unfinished_poly_image = unfinished_poly_image + hsv2rgb(temp_hsv);
					
					fprintf('first point: (%f, %f). Last point: (%f, %f)\n', polygon(1,1), polygon(1,2), polygon(end,1), polygon(end,2));
				end
			end
		end
		if ~isempty(polygons_to_remove)
			open_polygons(polygons_to_remove) = [];
		end
	end
	
	if ~isempty(closed_polygons)
		% pick the polygon with the largest inner area
		max_polygon_number = 0;
		max_polygon_area = 0;
		max_polygon_inner_px = [];
		max_polygon_border_px = [];
		max_path_pic = [];
		for i = 1 : length(closed_polygons)
			[path_pic, converted_path] = draw_path(closed_polygons{i}, 'pixelsize', image_size, 'range', range, 'fill', false);
			%figure;
			%imshow(path_pic);
			border_px = find(path_pic(:,:,2));
			inner_indices = get_closed_shape_inner_pixels(path_pic(:,:,2), converted_path);
			if numel(inner_indices) > max_polygon_area
				max_polygon_area = numel(inner_indices);
				max_polygon_number = i;
				max_polygon_inner_px = inner_indices;
				max_polygon_border_px = border_px;
				max_path_pic = path_pic;
			end
		end
		
		if max_polygon_area > 0
			border_image = border_image | max_path_pic(:,:,2);
			
			% check if this shape is inside any other shape
			% and if any other shape is inside the current one
			% and remove the pxs of the inside shape from the outside one
			if ~isempty(polygons)
				for i = 1 : length(polygons)
					curr_px = polygon_inner_px{i};
					if numel(curr_px) > max_polygon_area
						match_array = min(curr_px == max_polygon_inner_px(1), [], 2);
						if max(match_array(:)) == 1
							polygon_inner_px{i} = setdiff(curr_px, max_polygon_inner_px);
						end
					else
						% just want to make sure '==' doesn't get processed
						if numel(curr_px) < max_polygon_area
							match_array = min(max_polygon_inner_px == curr_px(1), [], 2);
							if max(match_array(:)) == 1
								max_polygon_inner_px = setdiff(max_polygon_inner_px, curr_px);
							end
						end
					end
				end
			end
			
			polygon_inner_areas(end+1) = max_polygon_area;
			polygons{end+1} = closed_polygons{max_polygon_number};
			polygon_inner_px{end+1} = max_polygon_inner_px;
			polygon_border_px{end+1} = max_polygon_border_px;
		end
	end
	
	if ~isempty(pairs_to_remove)		
		indices = [pairs_to_remove*2-1; pairs_to_remove*2];
		pairs(indices, :) = [];
	end
end

%figure;
%imshow(unfinished_poly_image);

%% sort polygons in the descending order of their inner areas
sort_array = [(1:length(polygons)).', polygon_inner_areas(:)];
sort_array = sortrows(sort_array, -2);
poly_order = sort_array(:,1);
polygons = polygons(poly_order);
polygon_inner_px = polygon_inner_px(poly_order);
polygon_border_px = polygon_border_px(poly_order);
%polygon_inner_areas = polygon_inner_areas(poly_order);

%% assign colors to shapes
colors = zeros(length(polygons), 1);
temp_image = zeros(image_size);
for i = 1 : length(polygons)
	outside_px = temp_image(polygon_border_px{i});
	outside_px = outside_px(:);
	color = ~round(sum(outside_px)/numel(outside_px)); % tehnically I only need to check one px, but I'll check them all to be safe. Maybe change that later...
	temp_image(polygon_inner_px{i}) = color;
	colors(i) = color;
end

%% draw all inner px in different colors
% hue_image = zeros(image_size);
% sat_image = zeros(image_size);
% val_image = zeros(image_size);
% for i = 1 : length(polygons)
% 	hue_image(polygon_inner_px{i}) = rand();
% 	val_image(polygon_inner_px{i}) = 1;
% 	sat_image(polygon_inner_px{i}) = rand;
% end
% areas_image = cat(3, hue_image, sat_image, val_image);
% areas_image = hsv2rgb(areas_image);
% figure; imshow(hsv2rgb(areas_image));

end

