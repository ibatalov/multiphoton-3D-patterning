function paths = trace_binary(image)

%% Split into connected components
CC = bwconncomp(image);
n_paths = 0;
paths = cell(CC.NumObjects, 1); % stores border paths for each isolated shape

[~, inds] = sort(cellfun(@(x) length(x), CC.PixelIdxList), 'descend');
CC.PixelIdxList = CC.PixelIdxList(inds);
%figure; imshow(image)
%figure;

%border_image = zeros([size(image,1)+2, size(image,2)+2,3]);
%slice1 = zeros(size(image)+2);
%slice2 = zeros(size(image)+2);

for obj_num = 1 : CC.NumObjects
	obj_ind = CC.PixelIdxList{obj_num};
	[obj_r, obj_c] = ind2sub(size(image), obj_ind);
	image_bounds = [min(obj_r), max(obj_r), min(obj_c), max(obj_c)];
	
	im = zeros(image_bounds(2) - image_bounds(1) + 3, image_bounds(4) - image_bounds(3) + 3);
	obj_r = obj_r - image_bounds(1) + 2;
	obj_c = obj_c - image_bounds(3) + 2;
	
	im(sub2ind(size(im), obj_r, obj_c)) = 1;
	%subplot(7,7,obj_num);
	%imshow(im);
	
	all_paths = [0,0,0,0];
	curr_row = 1;
	curr_col = 1;
	
	while (curr_row < size(im,1) - 1) || (curr_col < size(im, 2) - 1)
		path = [];
		%% find 1st border edge
		for row = curr_row : size(im,1) - 1
			for col = 1 : size(im, 2) - 1
				curr_row = row;
				curr_col = col;
				if im(row, col) ~= im(row+1,col)
					if im(row, col) > im(row+1,col)
						if sum(min(all_paths == [row, col, row+1, col], [], 2)) == 0
							path = [path; row, col, row+1, col];
							break
						end
					else
						if sum(min(all_paths == [row+1, col, row, col], [], 2)) == 0
							path = [path; row+1, col, row, col];
							break
						end
					end
				else
					if im(row, col) ~= im(row,col+1)
						if im(row, col) > im(row,col+1)
							if sum(min(all_paths == [row, col, row, col+1], [], 2)) == 0
								path = [path; row, col, row, col+1];
								break
							end
						else
							if sum(min(all_paths == [row, col+1, row, col], [], 2)) == 0
								path = [path; row, col+1, row, col];
								break
							end
						end
					end
				end
			end
			if ~isempty(path)
				break
			end
		end
		rot90 = [0, -1; 1, 0];
		if ~isempty(path)
			while sum(path(end,:) ~= path(1,:)) || (size(path, 1) == 1)
				e = path(end,:);
				p1 = e(1:2);
				p2 = e(3:4);
				%im(p1(1),p1(2))
				%im(p2(1), p2(2))
				a1 = p2 - p1;
				a2 = (rot90*a1.').';
				temp = p2 + a2;
				if im(temp(1), temp(2)) == 1
					path = [path; p2 + a2, p2];
				else
					temp = p1 + a2;
					if im(temp(1), temp(2)) == 1
						path = [path; p1 + a2, p2 + a2];
					else
						path = [path; p1, p1 + a2];
					end
				end
			end
			all_paths = [all_paths;path];
			path = path(1:end-1,:) + [image_bounds(1), image_bounds(3), image_bounds(1), image_bounds(3)] - 2;
			n_paths = n_paths + 1;
			paths{n_paths} = path;
			%"max path coords:"
			%max(path)

			%slice1(sub2ind(size(slice1), path(:,1)+1, path(:,2)+1)) = 1;	
			%slice2(sub2ind(size(slice2), path(:,3)+1, path(:,4)+1)) = 1;
		end
	end
end

%border_image(:,:,1) = slice1;
%border_image(:,:,2) = slice2;
%border_image(2:end-1,2:end-1,3) = image;
%figure; imshow(border_image)
end