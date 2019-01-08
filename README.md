# multiphoton-3D-patterning
Scripts to generate files for 2D and 3D light patterning using an Olympus multi-photon microscope

# generate_multiphoton_roi_file.m
This script takes a binary image, traces it with polygons, and converts it to a configuration file for FluoView (Olympus microscopy software)
This allows patterning of any 2D shape using 2-photon (or single photon) laser.

# genetare_roi_file_from_3d_coords.m
This script:

* takes and .obj file containing a 3D shape (use the simplest possible format - triangular faces, no materials, no extra features)

* slices it and finds the cross section of the object at each slice

* generates a microscopy configuration file for each slice.

Once you have those files, you can manually (or automatically) load them into the FluoView software, specify a z-position for each slice, and pattern any 3D object with light!
