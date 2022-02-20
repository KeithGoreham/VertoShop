--#################################################################
--## K's Vertoshop 2.0, A Vertex Color Editor for 3DS Max 4.2
--## Copyright  December 2005 by Keith Goreham
--#################################################################

--#################################################################
--## Summary of changes in version 1.1
--##
--## 1. Fixed a bug whereby a user could de-select the objects
--## being modified and crash the modifier being used. KVS now
--## immediately re-selects the prior selection if it changes
--## while a modifier is open.
--##
--## 2. Fixed a bug where a modifier would crash if the user made
--## an invalid masked vertex selection by defining vertex and face 
--## selections that did not overlap. This condition is now caught  
--## and an error message is displayed.
--##
--## 3. The color modifiers would crash if run on a Max release
--## earlier than 4.2. KVS now checks to make sure it's being run on 
--## a Max version of 4.2 or greater at startup. An error message is
--## dislayed if the script is run on an earlier version.
--##
--## 4. The KVS rollouts did not render consistently between Max 
--## versions 4.2 and 5.0. KVS now checks the Max version at 
--## startup and uses appropriate values for each version.
--##
--## 5. The modifier buttons on the KVS floater are now
--## automatically disabled when a modifier is run and re-enabled
--## when the modifier closes. This prevents the user from calling
--## more than one modifier at a time.
--##
--## 6. Web-based HTML help and faq items are now available at
--## http://www.goreham.com/maxscripts/kvs/help/index.htm.
--#################################################################

--#################################################################
--## Summary of changes in version 1.2
--##
--## 1. Rewrote the Brightness/Contrast modifier to use my own
--## custom brightness calculations instead of the flawed functions
--## included with 3D Studio Max. The results are much nicer.
--##
--## 2. Rewrote the Hue/Saturation/Value modifier to use my own 
--## saturation and value calculations instead of the flawed 
--## functions included with Max. The result is HSV changes which
--## are much more accurate than in Photoshop!
--#################################################################


--#################################################################
--## Script Globals
--#################################################################

kvsPanelHeight     = 345		-- This variable controls the height in pixels of the main KVS floater and the 'About VertoShop' floater.
kvsPanelWidth      = 172
aboutPanelWidth    = 330
rgbPanelHeight     = 220		-- This variable controls the height in pixels of the Red/Green/Blue modifier floater.
rgbPanelWidth      = 530		
hsvPanelHeight     = 220		-- This variable controls the height in pixels of the Hue/Saturation/Value modifier floater.
hsvPanelWidth      = 530
bcPanelHeight      = 158		-- This variable controls the height in pixels of the Brightness/Contrast modifier floater.
bcPanelWidth       = 530
xyzGradPanelHeight = 220		-- This variable controls the height in pixels of the XYZ Gradient modifier floater.
xyzGradPanelWidth  = 530
progFloatHeight    = 74			-- This variable contols the height in pixels of the various progress floaters.

--#################################################################
--## Start Code
--#################################################################
curMaxVer = maxVersion()		-- Grabs the current Max version as an array of different data. The release version will be a
								-- 4 digit number stored in the first array item.

if curMaxVer[1] < 7000 then		
(
	messagebox "Sorry, but KVS only supports Max releases of version 7.0 or greater." caption:"KVS Error!"
)
else
(
--#################################################################
--## Ok, first off we're going to declare all of the custom
--## functions that VertoShop will use. We'll package them all 
--## within a custom structure called 'KVS'. Thus, each function
--## will be called using 'kvs.[function name]'.
--##
--## This will lessen the possibility that the functions we write
--## for K's VertoShop will trample on the custom functions of 
--## other scripters or future ones we may write for our own tools.
--##
--## It also will help someone reading this code to tell the
--## difference between the default Max functions used here and the 
--## custom functions written for this tool. 
--#################################################################
	
	struct KVS
	(	
		-------------------------------------------------------------------
		-- This function checks all the objects selected and returns true
		-- if at least one editable mesh (or editable poly) is found.
		------------------------------------------------------------------
		function checkForMeshes =		
		(
			for curmesh in selection do
			(
				if (classof curmesh == editable_mesh) or (classof curmesh == editable_poly) then return true 	
			)
			return false
		),
		
		-------------------------------------------------------------------
		-- This function finds and returns the number of selected faces 
		-- found among all our selected mesh objects.
		-------------------------------------------------------------------
		function getSelObjSelFaces =	
		(
			facesCount = 0
		
			for curmesh in selection do
			(
				if (classof curmesh == editable_mesh) or (classof curmesh == editable_poly) then
				(
					facesCount = facesCount + curmesh.selectedfaces.count
				)
			)
			return facesCount
		),
		
		-------------------------------------------------------------------
		-- This function checkcs all objects selected and returns true if
		-- any editable mesh has faces selected.
		-------------------------------------------------------------------
		function checkForPolySel = 		
		(			
			for curmesh in selection do
			(
				if ((classof curmesh == editable_mesh) or (classof curmesh == editable_poly)) and (curmesh.selectedfaces.count != 0) then
				(
					return true 	
				)
			)
			return false
		),
		
		-------------------------------------------------------------------
		-- This function checks the selObjCPVs array and returns false if
		-- there is at least one CPV defined for each object.  
		-------------------------------------------------------------------
		function countCPVLessObjs selObjCPVs =
		(
			badObjCount = 0
	
			for i in 1 to selObjCPVs.count do
			(
				if selObjCPVs[i].count == 0 then
				(
					badObjCount += 1
				)
			)
			return badObjCount
		),
		
		-------------------------------------------------------------------
		-- This function updates the display for all the selected objects.
		-------------------------------------------------------------------	
		function updateAll =		
		(
			for curmesh in selection do update curmesh
		),
		
		-------------------------------------------------------------------
		-- This function returns all of the corresponding CPVs for a 
		-- single given mesh vertex. 
		--
		-- *The kvs.cleanCPVs function is dependent on this function.
		-------------------------------------------------------------------
		function getVertCPVs someMesh someVert =		
		(
			vertCPVs  = #()
			vertFaces = meshop.getfacesusingvert someMesh someVert
		
			for curface in vertFaces do			
			(
				faceVerts = getface   someMesh curface		
				colorFace = getVCface someMesh curface		
		
				CPVvert = case someVert of			
				(
					(faceVerts.x):colorFace.x as integer
					(faceVerts.y):colorFace.y as integer
					(faceVerts.z):colorFace.z as integer
				)
			
				if (finditem vertCPVs CPVvert) == 0 then 
				(
					append vertCPVs CPVvert
				)
			)
			vertCPVs
		),
		
		-------------------------------------------------------------------
		-- This function cleans up and rebuilds the CPV topology for an  
		-- object. It combines identical CPVs that share a common geometry  
		-- vertex and deletes any CPVs which are unused.
		-- 
		-- *This function is dependent on the kvs.getVertCPVs function which
		-- is defined above.
		-------------------------------------------------------------------
		function cleanCPVs someMesh =
		(
			vertColors = #()		        -- An array to hold the unique colors associated with each geovert.
			
			vertColorCPVIndexes = #()		-- An array to hold the new CPV indexes for the colors stored in vertColors. We'll
											-- use this array to match each unique CPV vertex/Color to a new CPV index.
			
			oldFaceColorTop = #()		-- An array to hold our old CPV face color topology.
			
			struct faceColors (x, y, z)		-- A structure to organize the colors we'll be storing in the oldFaceColorTop array.
		
			for curvert in someMesh.verts do				-- First we need to store the unique colors associated with geovert. We
															-- don't care how many CPVs use the same color because we're going to 
															-- build a new CPV topology based on the unique colors of each vertex. 
															-- We'll then query the color of each CPV face's verticies from the old
															-- topology to determine the new topology.
			(
				vertCPVs = kvs.getVertCPVs someMesh curvert.index 		-- Uses the kvs.getVertCPVs function defined earlier to grab all the CPVs
																		-- associated with this geovert. We'll then loop through them and store
																		-- the unique colors as a sub-array of vertcolors[i].
																	
				vertColors[curvert.index] = #()			-- initializes a sub-array of vertColors to hold the colors for this geovert.
		
				for i in 1 to vertCPVs.count do			-- Loops through each CPV found for the current vertex.
				(
					CPVcolor = getvertcolor someMesh vertCPVs[i]		-- grabs the color of the current CPV.
								
					if (finditem vertColors[curvert.index] CPVcolor == 0) then		-- And if it hasn't been stored already...
					(
						append vertColors[curvert.index] CPVcolor		-- It gets stored.
					)
				)
			)
		
			for curface in someMesh.faces do		-- Now we need to store the old CPV face topology so that we can reference
													-- it while we build our new topology. But instead of storing CPV indexes, 
													-- we'll be storing the actual colors of each face's CPV verts.
			(
				CPVface = getvcface someMesh curface.index		-- Grabs the CPV topology of the CPV face that matches up with the
																-- current geoface.
												   
				oldFaceColorTop[curface.index] = faceColors x:(getvertcolor someMesh CPVface.x) \		-- Stores the colors for each vertex of the current 
													   		y:(getvertcolor someMesh CPVface.y) \			-- face in oldFaceColorTop.
													   		z:(getvertcolor someMesh CPVface.z)
			)
			

			-- Now we need to determine a unique CPV index for each color stored in vertColors. The first color
			-- will have an index that is the same as the geometry vertex's index. But any colors beyond the first
			-- will need an index that doesn't conflict with any of the existing geometry indexes. We'll therefore
			-- use a formula where one of these 'extra' CPVs has an index equal to the total number of geometry 
			-- verticies, plus an offset. 
			
			indexOffset      = 1	 			-- We'll use this variable to keep track of our current index offset. 
			
			offsetvertcolors = #()				-- This array will keep track of the colors for each offset vert since there
												-- will be no consistent way of referenceing them later.
			
			
			for i in 1 to vertColors.count do		-- This loop will go through each set of stored colors in vertColors and
													-- store a new unique CPV index in vertColorCPVIndexes for that vertex/color.
			(
				vertColorCPVIndexes[i] = #()		-- Initializes a sub-array of vertColorCPVIndexes[i] for the current vertex.
				
				for j in 1 to vertColors[i].count do		-- Steps through each color stored for the current vertex.
				(
					if (j == 1) then		-- If the current color is the first in the list for this vertex...
					(
						vertColorCPVIndexes[i][j] = i		-- It's CPV index will be the same as the vert's geometry index.
					)			
					else		-- If the current color is not the first in the list for this vertex...
					(
						vertColorCPVIndexes[i][j] = someMesh.verts.count + indexOffset		-- It's index is equal to the total number of geoverts in the
																							-- object plus the current offset.
						
						offsetvertcolors[indexOffset] = vertcolors[i][j]		-- And it's color is stored in the offsetVertcolors array.
						
						indexOffset += 1		-- And then we iterate the offset by one.
					)
				)
			)
			
			-- Ok, now we rebuild the CPV topology.	
			
			setnumcpvverts someMesh (someMesh.verts.count + (indexOffset - 1))		-- First we define the new number of CPVs for this object as the total 
																					-- number of geoverts plus the last value of indexOffset (minus one).
																			
			For curface in someMesh.faces do		-- Now we'll build the CPV faces by going through each geometry face and
													-- comparing it's prior color topology (as stored in oldFaceColorTop) to the 
													-- unique colors we found for each geometry vertex that makes up that face.
			(
				thisface = getface someMesh curface.index		-- Grabs the vertex topography of the current face.
				
				thisface.x = thisface.x as integer			-- For whatever damn reason the vertex indexes always come back 
				thisface.y = thisface.y as integer			-- as a float instead of an integer. Here we convert them to
	

				thisface.z = thisface.z as integer			-- integers so they cause fewer problems later.
				
				-- Now we need to figure out which CPV index corresponds to each component of the current CPV face.
				-- The three lines above give us the geoverts for the current face. But they don't tell us which of
				-- the CPV vert indexes stored in vertcolorCPVindexes[vertex] we need. The following lines compare
				-- the x, y, and z colors stored in oldFaceColortop[face] with the colors stored in 
				-- vertColors which match up with that geometry vertex. The index thus found is the index for the 
				-- proper CPV index in vertcolorCPVs for that vert.
				--
				-- Example: The current face ID is 1. And it has a geometry topography of [1,2,3]. So thisface.x = 1.
				-- 		  Looking at the stored color for the x vert of face 1 in oldFaceColorTop we find that the
				--		  proper color of thisface.x = red. Or (color 255 0 0). We then do a finditem for red in
				--		  vertColors[1]. There are 3 colors stored for geometry vertex one (Blue, Red, and Green).  
				--		  So our finditem operation returns an xIndex of 2. So we now know that the proper CPV index 
				--		  for CPV face number 1.x is stored in vertColorCPVindexes[1][2].
				
				xIndex = finditem vertcolors[thisface.x] oldFaceColorTop[curface.index].x 
				yIndex = finditem vertcolors[thisface.y] oldFaceColorTop[curface.index].y
				zIndex = finditem vertcolors[thisface.z] oldFaceColorTop[curface.index].z
				
				xCPV = vertColorCPVindexes[thisface.x][xIndex]
				yCPV = vertColorCPVindexes[thisface.y][yIndex]
				zCPV = vertColorCPVindexes[thisface.z][zindex]
				
				setVCFace someMesh curface.index [xCPV, yCPV, zCPV]			-- Sets the CPV topography for the current geoface's corresponding CPV face.
			)
			
			for i in 1 to (getnumcpvverts someMesh) do		-- This loop assigns each CPV's color.
			(
				if (i <= (getnumverts someMesh)) then		-- If the current CPV index is less than or equal to the total number o
															-- geometry verts in the object then it's color is equal to the first color
															-- stored for that vertex in vertColors.
				(
					setvertcolor someMesh i vertcolors[i][1]
				)
				else										-- But if the current CPV index is greater than the total number of geometry
															-- verts in the object, then it's color is equal to the corresponding color
															-- stored in offsetvertcolors. The index for which is found by subtracting the
															-- total number of geometry verts in the object from the current CPV index.
				(
					setvertcolor someMesh i offsetvertcolors[i - getnumverts someMesh]
				)
			)	
			
			update someMesh			-- Updates the object in the 3dsMax viewport.

		),
	
		
		-------------------------------------------------------------------
		-- This function returns a bitarray of CPVs for a given object.
		--
		-- *This function is dependent on the kvs.getVertCPVs function which
		-- is defined above.
		-------------------------------------------------------------------
		function objToCPVs someMesh =
		(
			objCPVs = #()		-- Array to hold all the object CPVs we find.
		
			-- Now we could simply return every CPV in the object to the calling
			-- operation. But I think it's a bit more useful to make sure that every
			-- CPV we return is actually used in the object. And not simply an extra
			-- CPV vertex produced by some glitchy tool like Max's default vertex
			-- color picker. So we'll go through each geometry vert and store every 
			-- unique CPV that matches up with it. In this way any extra CPVs will
			-- not be passed on to the color modifiers.
			
			for i in 1 to someMesh.verts.count do					
			(
				vertCPVs = kvs.getVertCPVs someMesh i				-- Uses the kvs.getVertCPVs function defined above to retrieve all of the
																	-- CPV verts that correspond to the given vertex.
																	
				for curCPV in vertCPVs do		-- Steps through each CPV found from interrogating the current geometry vertex.
				(
					if (finditem objCPVs curCPV == 0) then append objCPVs curCPV		-- And stores that CPV if it's unique.
				)
			)
			return objCPVs as bitarray			-- Returns the array of CPV verts back to the calling operation as a bitarray.
		),
		
		-------------------------------------------------------------------
		-- This function returns an array of the CPVs which match up with
		-- all of the selected geometry verticies. 
		--
		-- *This function is dependent on the kvs.getVertCPVs function which
		-- is defined above.
		-------------------------------------------------------------------
		function vertSelToCPVs somemesh =
		(
			objCPVs  = #()		-- Array to hold all the object CPVs we find.
			
			for i in 1 to someMesh.selectedVerts.count do					-- Steps through every selected vert in the object.
			(
				vertCPVs = kvs.getVertCPVs someMesh i		-- Uses the kvs.getVertCPVs function defined above to retrieve all of the
															-- CPV verts that correspond to the given vertex.
															
				for j in 1 to vertCPVs.count do		-- Steps through each retrieved CPV vertex.
				(
					if (finditem objCPVs curCPV == 0) then append objCPVs j		-- Add adds it to the objCPV array if it's not there already.
				)		
			)
			return objCPVs as bitarray		-- Returns the array of CPV verts back to the calling operation as a bitarray.
		),
		
		-------------------------------------------------------------------
		-- This function returns an array of the CPVs which match up with
		-- an object's selected geometry faces. If any selected face CPVs 
		-- are shared with un-selected faces, this function will rebuild 
		-- the object's CPV topology so that those CPVs are not shared. 
		-- (This is so we get nice hard edges from color changes made to 
		-- face selections.)
		-------------------------------------------------------------------	
		function faceSelToCPVs somemesh =
		(
			selFaceCPVs   = #{}		-- Bitarray to hold our object's selected face CPVs.
			unSelFaceCPVs = #{}		-- Bitarray to hold our object's un-selected face CPVs.
			
			for curface in somemesh.selectedfaces do		-- For each selected face...
			(	
				faceCPVs = getvcface somemesh curface.index			-- Get that face's CPVs. The next bit adds them to the bitarray if
																	-- they're not there already.
						
				if (finditem selFaceCPVs faceCPVs.x == 0) then append selFaceCPVs faceCPVs.x
				if (finditem selFaceCPVs faceCPVs.y == 0) then append selFaceCPVs faceCPVs.y
				if (finditem selFaceCPVs faceCPVs.z == 0) then append selFaceCPVs faceCPVs.z	 
			)
			
			for curface in (somemesh.faces as bitarray - somemesh.selectedfaces as bitarray) do		-- For each un-selected face...
			(
				faceCPVs = getvcface somemesh curface		-- Get that face's CPVs. The next bit adds them to the bitarray if
															-- they're not there already.
				
				if (finditem unSelFaceCPVs faceCPVs.x == 0) then append unSelFaceCPVs faceCPVs.x
				if (finditem unSelFaceCPVs faceCPVs.y == 0) then append unSelFaceCPVs faceCPVs.y
				if (finditem unSelFaceCPVs faceCPVs.z == 0) then append unSelFaceCPVs faceCPVs.z
			)
		
			inCommonCPVchk = selFaceCPVs - unSelFaceCPVs		-- Now that we have 2 bitarrays containing the CPVs for the selected and un-selected
																-- faces we'll check to see if any selected face CPVs also belong to faces which are
																-- un-selected. If so, we'll need to rebuild the object's CPVs so that there are no
																-- CPVs shared between the selected and unselected faces. First we'll subtract the
																-- un-selected face CPVs from the bitarray of selected face CPVs.
			
			if ((inCommonCPVchk as array).count != (selFaceCPVs as array).count) then		-- Now we compare the bitarray of selected face CPVs to the new bitarray of 
																							-- selected face CPVs with the un-selected face CPVs subtracted. If the two 
																							-- arrays have the same count then we that no CPVs are shared between the 
																							-- two groups. And we can just pass on the CPV bitarray to the operation  
																							-- that called the function. If the two are different then we know we need  
																							-- to rebuild the object CPVs so that there is no crossover.
			(
				sharedCPVs = #{}		-- A bitarray to hold the CPVs that are shared between the selected and un-selected faces.
				
				for curCPV in selFaceCPVs do		-- Now we'll build our bitarray of shared CPVs by stepping through each CPV in
													-- our bitarray of selected face CPVs and seeing if it's also in the bitarray of
													-- un-selected face CPVs. If it is, we add it.
				(
					if (finditem unSelFaceCPVs curCPV != 0) then append sharedCPVs curCPV
				)		
				
				cpvFaces  = #()			-- An array to hold the topology of the object's CPV faces.
				cpvColors = #()			-- An array to hold the object's CPV color values.
				
				for i in 1 to (getnumcpvverts somemesh) do		-- This loop copies the object's existing CPV color values to our cpvColors array.
				(
					cpvColors[i] = getvertcolor someMesh i
				)
				
				faceSel = (someMesh.selectedfaces as bitarray) as array	
				
				for i in 1 to getnumfaces somemesh do		-- Steps through each of the object's faces.
				(
					cpvFaces[i] = getvcface somemesh i		-- And copies that face's CPV topology to cpvFaces
					
					if (finditem faceSel i != 0) then		-- If this face is selected...
					(
						for j in 1 to 3 do		-- Then we'll step through each of it's CPVs.
						(
							if (finditem sharedCPVs cpvFaces[i][j] != 0) then		-- And if this CPV is in the list of shared CPVs we'll replace the 
																					-- index stored in cpvFaces with a new one.
							(
								cpvFaces[i][j] = (getnumcpvverts someMesh) + (finditem (sharedCPVs as array) cpvFaces[i][j])
							)
						)
					)
				)
				
				oldCount = cpvColors.count		-- Now we're going to start adding more values to to cpvcolors to cover the
												-- new CPVs we're going to add. This variable will hold the old number of
												-- colors so that as we add new values we can keep track of where we started.
				
				for i in 1 to (sharedCPVs as array).count do		-- This loop adds a new color to cpvColors for each CPV we're going to
																	-- add later. That color will be the same as the original shared CPV.
				(
					cpvColors[oldCount + i] = getvertcolor someMesh (sharedCPVs as array)[i] 
				)
				
				setnumcpvverts someMesh (oldCount + (sharedCPVs as array).count)		-- Adds an additional CPV to the object for each of our shared CPVs. 
				
				for i in 1 to getnumfaces someMesh do		-- This loop steps through each face of the object and builds a new
															-- CPV face based on the changes we made to cpvFaces.
				(
					setVCface someMesh i cpvFaces[i]
				)
				
				for i in 1 to getnumcpvverts someMesh do	-- This loop steps through each CPV of the object and assigns it a new color from cpvcolors.
				(
					setvertcolor someMesh i cpvColors[i]
				)
														
				selFaceCPVs = selFaceCPVs as array		-- Now, the last thing we need to do is to correct the indexes stored in the selFaceCPV
														-- array so that they reflect the changes made during the object's CPV rebuild. First,
														-- we'll convert the bitarray to an array so that we can edit the indexes it stores.
				
				for i in 1 to selFaceCPVs.count do		-- Then, we'll step through each index stored in the array...
				(
					if (finditem sharedCPVs selFaceCPVs[i] != 0) then		-- And if that index is in the sharedCPV bitarray...
					(
						 selFaceCPVs[i] = oldCount + finditem (sharedCPVs as array) selFaceCPVs[i]		-- We'll change the selFaceCPV index to the proper value. 
					)
				)
		
				selFaceCPVs as bitarray 		-- Passes the bitarray of selected face CPVs back to the caller.	
			)
			else		-- Called if no CPV topology rebuild is needed.
			(
				selFaceCPVs			-- Passes the bitarray of selected face CPVs back to the caller.
			)
		),
	
		-------------------------------------------------------------------
		-- These two functions pop up a floater with a predefined progress
		-- bar and label on it. The first is used while the object CPV
		-- selections are being built. The second is used during the 
		-- cleanup stage after the user has clicked OK or Cancel on the
		-- modifier rollout. The only difference between them is the
		-- text on the title bar and rollout. The reason for defining 
		-- them this way is that a rollout will not accept a text
		-- variable when defining the text used in it title bar. So you
		-- can't pass the title you want as a function argument. <grumble>
		--
		-- You also have to set a variable (I suggest 'rollProgress'.) to 
		-- the result of either function or you won't be able to manipulate
		-- the progress bar and text label later due to scope issues with
		-- the created rollout.
		-------------------------------------------------------------------
		function prepProgFloater =
		(
			global progFloater = newrolloutfloater "Preparing Selected Objects..." 480 progFloatHeight 		-- Our progress floater.
		
			rollout rollProgress "Preparing Objects..."		-- Our progress rollout.
			(
				progressbar progress color:red			-- A progress bar that will show our progress when
														-- processing the object CPV selections.
											
				label workingon "" align:#left			-- A label that we will update at each stage of
														-- the script to show where we are in the process.
			)
			
			addrollout rollProgress progFloater			-- Adds the rollout to the floater.
			
			rollProgress		-- Returns the rollout handle to the caller so that we
								-- can manipulate the progress bar and text label later
								-- using whatever variable we assign to the function's 
								-- output. 
								--
								-- example: '[variable].progress.value = 50' would set
								-- 			the progress bar to the half-way mark.
		),
		
		function cleanProgFloater =
		(
			global progFloater = newrolloutfloater "Cleaning Up Objects..." 480 progFloatHeight		-- Our progress floater.
		
			rollout rollProgress "Cleaning Objects..."		-- Our progress rollout.
			(
				progressbar progress color:red			-- A progress bar that will show our progress when
														-- processing the object CPV selections.
											
				label workingon "" align:#left			-- A label that we will update at each stage of
														-- the script to show where we are in the process.
			)
			
			addrollout rollProgress progFloater			-- Adds the rollout to the floater.
			
			rollprogress		-- Returns the rollout handle to the caller so that we
								-- can manipulate the progress bar and text label later
								-- using whatever variable we assign to the function's 
								-- output. 
								--
								-- example: '[variable].progress.value = 50' would set
								-- 			the progress bar to the half-way mark.
		),
	
		-------------------------------------------------------------------
		-- This function steps through each mesh object selected and does a 
		-- couple of things:
		--
		-- 1. If the object does not already have a CPV topology, one is
		-- built for it.
		--
		-- 2. Depending on the selection mode (object, vert, or face)
		-- this function creates a list of relevent CPVs for each mesh as
		-- a sub-array of selObjCPVs. It does this using the objToCPVs, 
		-- vertSelToCPVs, and faceSelToCPVs functions defined above. In the
		-- case of a masked vert selection, the faceSelToCPVs function is
		-- applied first. Followed by the vertSelToCPVs function. The two
		-- bitarrays are then compared and the common CPVs saved to
		-- selObjCPVs before returning the contents of selObjCPVs to the
		-- caller.
		-------------------------------------------------------------------
		function buildObjCPVlist rollProgress selSubObjectLevel vertMask =
		(
			global objsIgnored = 0			-- Variable to hold the number of non-mesh objects ignored by the pre-processing step
											-- for the purpose of notifying the user of how many objects were ignored.
			
			selObjCPVs = #()				-- An array to hold the selected CPVs for the HSV modifier as a series of sub-arrays
											-- corresponding to each selected mesh object.
			
			for i in 1 to selection.count do
			(
				rollProgress.workingon.text = ("Processing: " + selection[i].name as string + "...")
			
				if (classof selection[i] == editable_mesh) then		-- If the current object is an editable mesh...
				(
					collapsestack selection[i]		-- Collapses the stack for the current mesh object. We have to do this because
													-- you can't change the CPV topography of an editable mesh with a modifier applied.
				
					selection[i].showvertexcolors = true			-- Turn on it's vertex color display.
					
					if (getnumcpvverts selection[i] == 0) then		-- If the current mesh object doesn't have any CPVs already then
																	-- we'll need to assign CPV verts and build the CPV face topology.
					(
						setnumcpvverts selection[i] selection[i].verts.count		-- Sets the number of CPV verts as equal to the number of geometry verts.
						
						defaultvcfaces selection[i]		-- Builds the default CPV faces for the object.
						
						for curvert in selection[i].verts do			-- Steps through each vertex in the object. Which in this virgin
																		-- mesh will still match up perfectly with the geometry verts.
						(
							setvertcolor selection[i] curvert.index white			-- And we'll set each CPV's color to white.					
						)
						
						update selection[i]		-- Updates the viewport display for the current object.
					)
					
					-- Now to store the CPVs that we'll be manipulating.
					
					if (selSubObjectLevel == 0) then			-- If the modifier was called at the object level...
					(
						selObjCPVs[i] = kvs.objToCPVs selection[i]			-- Then use the kvs.objToCPVs function to find the CPVs to modify and add them to selObjCPVs[i].
					)
					else if (selSubObjectLevel == 1) and (vertMask == true) then		-- If the modifier was called at the vertex level and 
																						-- the mask_verts checkbox is checked...
					(
						-- Now you might think that to limit our vertex selection to the selected faces we could just do a bitwise 'and' operation 
						-- between the results of the faceSelCPVs and vertSelCPVs functions by inverting the difference between the two resulting 
						-- bitarrays. But alas, this doesn't !#@$% work. It always yields selections that are the opposite of whatever the original 
						-- vertex selection was. So we're forced to do it the hard way by converting both bitarrays to regular arrays and looping 
						-- through them. Comparing their contents one CPV at a time. <sigh>
					
						faceSelCPVs = kvs.faceSelToCPVs selection[i] as array		-- Grabs all the CPVs associated with the current object's selected faces. It's 
																					-- important to find the face CPVs first because the kvs.faceSelToCPVs function will 
																					-- almost always change the CPV topology of the object.
						
						vertSelCPVs = kvs.vertSelToCPVs selection[i] as array		-- Grabs all the CPVs associated with the current object's selected verticies.
						
						selObjCPVs[i] = #()			-- Defines selObjCPVs[i] as an array so that we can add CPVs to it.
						
						for j in 1 to vertSelCPVs.count do		-- Loops through each CPV stored in vertSelCPVs.
						(
							if (finditem faceselCPVs vertSelCPVs[j] != 0) then		-- And if the current CPV is found in faceSelCPVs...
							(
								append selObjCPVs[i] vertSelCPVs[j]			-- Then add it to the selObjCPVs[i] array.
							)
						)
						
						selObjCPVs[i] = selObjCPVs[i] as bitarray		-- Converts the selObjCPVs[i] array into a bitarray (uses less RAM and loops faster).
					)				
					else if (selSubObjectLevel == 1) then		-- If the modifier was called at the vertex level (And the mask_verts checkbox is not checked)...
					(
						selObjCPVs[i] = kvs.vertSelToCPVs selection[i]			-- Then use the kvs.vertSelToCPVs function to find which CPVs correspond to the
																			-- selected geoverts and add them to selObjCPVs[i].
					)				
					else			-- If the modifier was called at one of the face-selection generating levels (face,
									-- polygon, or element)... (Because you can't press the button if you're in edge mode.
									-- And we tested for the only other possibilities above.
					(
						selObjCPVs[i] = kvs.faceSelToCPVs selection[i]		-- Then use the kvs.faceSelToCPVs function to find which CPVs correspond to the selected
																		-- faces and add them to selObjCPVs[i].
					)
						
					rollProgress.progress.value = (50 / selection.count) * i		-- Updates the progress bar.
				)
				else		-- If the current object is not an editable mesh...
				(
					selObjCPVs[i] = #{}		-- An empty bit-array will be stored in selObjCPVs for the current object.
				
					objsIgnored += 1		-- Then we iterate the objsIgnored count.
					
					rollProgress.progress.value = (50 / selection.count) * i		    -- And update the progress bar.	Notice that we only top out at 50% progress
																						-- with this function as we will still need to fetch a list of actual CPV colors
																						-- after this function completes. The next function will therefore take us the  
																						-- rest of the way from 50% - 100%.
				)
			)
			selObjCPVs		-- Returns the list of objectCPVs back to the caller.
		),
		
		-------------------------------------------------------------------
		-- This function takes the array of CPVs generated by the previous
		-- function and stores all of the corresponding colors in a 
		-- matching array of it's own. Thus, when the color modifiers are 
		-- called, we'll have a list of what all the colors we're 
		-- modifying were originally to work with and, if neccessary, 
		-- revert to.
		-------------------------------------------------------------------
		
		function buildObjCPVColorlist selObjCPVs rollProgress =
		(
			selObjCPVColors = #()			-- Our array to hold the colors that correspond to the CPVs stored in 'selObjCPVs'.
		
			for i in 1 to selObjCPVs.count do		-- For each array stored in selObjCPVs...
			(
				rollProgress.workingon.text = ("Grabbing existing colors for: " + selection[i].name as string + "...")		-- We first update the progress bar text.
			
				selObjCPVColors[i] = #()		-- Then we initialize a sub-array of selObjCPVColors to hold the colors for this object.
			
				for j in 1 to selObjCPVs[i].count do		-- Iterates through all of the CPVs stored for the current mesh.
				(
					selObjCPVColors[i][j] = getVertColor selection[i] selobjcpvs[i][j]			-- And stores each CPV's color in selObjCPVColors.
				)
				
				rollProgress.progress.value = ((50 / selection.count) * i) + 50			-- Updates the progress bar. We're skewing the result into the 50-100% range
																						-- because the previous (kvs.buildObjCPVlist) function will have updated the 
																						-- progress bar from 0-50% when it was called to build the CPV list.
			)
			selObjCPVColors		-- Returns the list of CPV colors back to the caller.
		),
		
		-------------------------------------------------------------------
		-- This function takes a list of CPVs and stores the x, y, or z  
		-- position of each CPV's geovert parent in a matching array of  
		-- it's own. Thus the XYZ gradient modifier will have a list of 
		-- vert positions that it can use to determine what color each CPV 
		-- should be.
		--
		-- *This function is dependent on the kvs.getVertCPVs function 
		-- which is defined above.
		-------------------------------------------------------------------
		function buildObjCPVPosList selobjCPVs gAxis =
		(
			selObjCPVPositions = #()		-- Our array to hold the positions that correspond to the CPVs stored in 'selObjCPVs'.
	
			for i in 1 to selObjCPVs.count do		-- For each array stored in selObjCPVs...
			(	
				selObjCPVPositions[i] = #()		-- Then we initialize a sub-array of selObjCPVPositions to hold the positions for this object.
				
				global cpvsByVert = #()		-- An array to hold the current object's CPVs indexed by geometry vertex.
				
				for j in 1 to selection[i].verts.count do		-- This for loop steps through each geometry vertex of the current
																-- object and stores the CPVs for that vertex in a subarray of
																-- cpvsByVert. That way we can find the geovert for each CPV we're
																-- interested in and query it's x, y, or z position.
				(
					cpvsByVert[j] = kvs.getVertCPVs selection[i] j		-- Uses the kvs.getVertCPVs function defined above to store
																		-- the CPVs for the current geometry vertex.
				)
				
				for j in 1 to selObjCPVs[i].count do		-- This for loop will step through each selected CPV for the current object. We'll
															-- then use the following code to find and store that CPV's geometry vertex.
				(
					curCPV = selObjCPVs[i][j]		-- Stores the current CPV index we're attempting to match.
				
					if (curCPV <= selection[i].verts.count) and (finditem cpvsByVert[curCPV] curcpv != 0) then		-- This first if statement is a timesaving measure. Any object
																													-- who's CPV topology has been rebuilt by KVS (Which happens
																													-- whenever a modifier panel is closed.) has a pedictable
																													-- relationship between it's CPV and geometry verts. Any vert
																													-- index equal to or less than the total number of geometry verts
																													-- will have the same index as that geometry vert. So if our 
																													-- current CPV's index is equal to or less than the total number
																													-- of geoverts we automatically check the CPVs stored in 
																													-- cpvsByVert for the like indexed geovert to see if we have a 
																													-- match. When working with KVS-modified objects, this saves
																													-- lots of processing time since we can skip the following while
																													-- loop most of the time.
					(																								
						selObjCPVPositions[i][j] = case gAxis of		-- Here we store the x, y, or z position of the found vertex according to the desired axis.
						(
							1:(selection[i].verts[curCPV].pos.x)
							2:(selection[i].verts[curCPV].pos.y)
							3:(selection[i].verts[curCPV].pos.z)
						)
					)
					else		-- So if our shortcut check didn't produce a match, we now have to do things the slow way and loop through
								-- each vert's CPVs as stored in cpvsByVert looking for a match to our current CPV. 
					(
						k = 1		-- This will be our iteration variable for the following while loop. We're not using a
									-- for loop here because we want to be able to exit the loop once we find our match.
									-- That way we save time.
						
						while (k <= cpvsByVert.count) do		-- So while k's value is less than the total number of arrays stored in cpvsByVert...
						(
							if (finditem cpvsByVert[k] selObjCPVs[i][j] != 0) then			-- We check the stored CPVs for the current vert to see if we have a match.
							(
								selObjCPVPositions[i][j] = case gAxis of		-- Here we store the x, y, or z position of the found vertex according to the desired axis.
								(
									1:(selection[i].verts[k].pos.x)
									2:(selection[i].verts[k].pos.y)
									3:(selection[i].verts[k].pos.z)
								)
								
								exit		-- Exits the while loop. No point in wasting time letting the loop run out on it's own.
							)
							k += 1		-- Iterates k by one.
						)
					)
				)
			)
			selObjCPVPositions		-- Echos the array of CPV positions back to the caller.
		),
		
		
		-------------------------------------------------------------------
		-- This function will go through the current selection and
		-- generate a new array that does not include any non-mesh objects.
		-- By setting the selection to the output of this function you 
		-- therefore cull any objects that would crash the vertex color
		-- modifiers. This function will also throw up a messagebox to
		-- let the user know how many objects have been dropped. 
		-------------------------------------------------------------------
		function nonMeshSelCull =
		(
			culledSelection = #()		-- An array to hold our new post-cull selection.
			
			for curObj in selection do		-- Steps through each selected object.
			(
				if (classof curObj == Editable_Mesh) then append culledSelection curObj			-- And if the current object is an editable mesh, it 
																								-- gets appended to culledSelection.
			)
			
			if (selection.count != culledSelection.count) then			-- If the new array is smaller than the original selection, we'll throw
																		-- up a messagebox to tell the user how many objects were dropped.
			(
				messagebox ((selection.count - culledSelection.count) as string + " non-mesh objects have been de-selected.") title:"Objects"
			)
			
			culledSelection			-- Returns the culled selection back to the caller.
		),	
		
		-------------------------------------------------------------------
		-- The Red/Green/Blue change function for the RGB modifier.
		-------------------------------------------------------------------
		function rgbChange selObjCPVs selObjCPVColors redVal greenVal blueVal =
		(
			for i in 1 to selObjCPVs.count do		-- Steps through each array of object CPVs stored in selObjCPVs.
			(
				for j in 1 to selObjCPVs[i].count do		-- Steps through each CPV for the current object.
				(
					oldColor = selObjCPVColors[i][j]		-- Grabs the color for the current CPV.
					
					newColor = copy oldColor		-- Copies the current color. We'll make changes to newColor 
													-- before writing it to the object.
													
					-- The Red Calculation.
					
					if (oldColor.red + redVal > 255) then newColor.red = 255
					if (oldColor.red + redVal < 0)   then newColor.red = 0
					else								  newColor.red = (oldColor.red + redVal) as integer
					
					-- The Green Calculation.
					
					if (oldColor.green + greenVal > 255) then newColor.green = 255
					if (oldColor.green + greenVal < 0)   then newColor.green = 0
					else								      newColor.green = (oldColor.green + greenVal) as integer
								
					-- The Blue Calculation.
					
					if (oldColor.blue + blueVal > 255) then newColor.blue = 255
					if (oldColor.blue + blueVal < 0)   then newColor.blue = 0
					else								    newColor.blue = (oldColor.blue + blueVal) as integer
					
					-- These statements make sure that we don't store a red, green, or blue value that is out of range.
					
					if (newColor.red > 255) then newColor.red = 255
					if (newColor.red < 0)   then newColor.red = 0
					
					if (newColor.blue > 255) then newColor.blue = 255
					if (newColor.blue < 0)   then newColor.blue = 0
					
					if (newColor.green > 255) then newColor.green = 255
					if (newColor.green < 0)   then newColor.green = 0
					
					setvertcolor selection[i] selObjCPVs[i][j] newColor		-- Assigns the new color to the current CPV.
				)
			)
		),	
		
		
		-------------------------------------------------------------------
		-- This function finds the saturation of a color.
		-------------------------------------------------------------------
		function findSaturation someColor = 
		(
			hueRange = floor(someColor.hue / 42.5)
	
			sat = case hueRange of
			(
				0: someColor.red   - someColor.blue
				1: someColor.green - someColor.blue
				2: someColor.green - someColor.red
				3: someColor.blue  - someColor.red
				4: someColor.blue  - someColor.green
				5: someColor.red   - someColor.green
				6: someColor.red   - someColor.blue
			)
			
			return sat
		),
		
		-------------------------------------------------------------------
		-- This function finds the value of a color.
		-------------------------------------------------------------------
		function findValue someColor =
		(
			hueValCorrection = 1.0 - (findPureHueValue someColor)
			colorSat  = findSaturation someColor
						
			hueRange = floor(someColor.hue / 42.5)
	
			val = case hueRange of
			(
				-- Red to Yellow
				0: someColor.red   - (colorSat * hueValCorrection) 
				-- Yellow to Green
				1: someColor.green - (colorSat * hueValCorrection) 
				-- Green to Cyan
				2: someColor.green - (colorSat * hueValCorrection)
				-- Cyan to Blue
				3: someColor.blue  - (colorSat * hueValCorrection)
				-- Blue to Magenta
				4: someColor.blue  - (colorSat * hueValCorrection)
				-- Magenta to Red
				5: someColor.red   - (colorSat * hueValCorrection)
				-- Pure Red
				6: someColor.red   - (colorSat * hueValCorrection)
			)
	
			return val 
		),
		
		-------------------------------------------------------------------
		-- This function properly modifies a color's value.
		-------------------------------------------------------------------
		function adjustColorVal someColor someValAdj =
		(
			hueRange = floor(someColor.hue / 42.5)
		
			-- First we figure out our maximum, minimum, and middle components.
			maxMinMid = case hueRange of
			(
				-- Red to Yellow
				0: [someColor.red, someColor.blue, someColor.green]
				-- Yellow to Green
				1: [someColor.green, someColor.blue, someColor.red] 
				-- Green to Cyan
				2: [someColor.green, someColor.red, someColor.blue]
				-- Cyan to Blue
				3: [someColor.blue, someColor.red, someColor.green]
				-- Blue to Magenta
				4: [someColor.blue, someColor.green, someColor.red]
				-- Magenta to Red
				5: [someColor.red, someColor.green, someColor.blue]
				-- Pure Red
				6: [someColor.red, someColor.blue, someColor.green]
			)
			
			-- Now we calculate the saturation.
			sat = maxMinMid[1] - maxMinMid[2]
			
			-- Then we calculate the ratio between mid - min and the saturation
			midRatio = (maxMinMid[3] - maxMinMid[2]) / sat
			
			-- Then we add the value adjustment.
			maxMinMid += someValAdj
			
			-- If the value adjustment takes our min below zero, we need to adjust the
			-- mid back up by an appropriate fraction of the total adjustment.
			if maxMinMid[2] < 0.0 then
			(
				-- Set the min to zero.
				maxMinMid[2] = 0
				
				-- And correct the mid.
				maxMinMid[3] = maxMinMid[1] * midRatio
			)
			
			-- If the value adjustment takes our max above 255, we need to adjust the
			-- mid component back down by an appropriate fraction of the total adjustment.
			if maxMinMid[1] > 255.0 then
			(				
				-- Set the max to 255.
				maxMinMid[1] = 255.0
				
				-- And correct the mid
				maxMinMid[3] = ((255.0 - maxMinMid[2]) * midRatio) + maxMinMid[2]
			)
			
			maxMinMid = case hueRange of
			(
				-- Red to Yellow
				0: [maxMinMid[1], maxMinMid[3], maxMinMid[2]]
				-- Yellow to Green
				1: [maxMinMid[3], maxMinMid[1], maxMinMid[2]] 
				-- Green to Cyan
				2: [maxMinMid[2], maxMinMid[1], maxMinMid[3]]
				-- Cyan to Blue
				3: [maxMinMid[2], maxMinMid[3], maxMinMid[1]]
				-- Blue to Magenta
				4: [maxMinMid[3], maxMinMid[2], maxMinMid[1]]
				-- Magenta to Red
				5: [maxMinMid[1], maxMinMid[2], maxMinMid[3]]
				-- Pure Red
				6: [maxMinMid[1], maxMinMid[3], maxMinMid[2]]
			)
			
			return maxMinMid as color
		),
		
		-------------------------------------------------------------------
		-- The Hue/Saturation/Value change function for the HSV modifier.
		-------------------------------------------------------------------
		function hsvChange selObjCPVs selObjCPVColors hueVal satVal valVal hueMerge =
		(	
			for i in 1 to selObjCPVs.count do			-- Steps through each array of object CPVs stored in selObjCPVs.
			(
				for j in 1 to selObjCPVs[i].count do		-- Steps through each CPV for the current object.
				(
					oldColor = selObjCPVColors[i][j]		-- Grabs the color for the current CPV. 
					
					newColor = copy oldColor	-- Copies the current color. We'll make changes to newColor 
												-- before writing it to the object.
					
					-- The Hue Calculation. (This is the only part of the built-in HSV calculation that's not wrong in Max.)
					if (hueMerge == true) then 		-- If the Merge Hues checkbox is checked we'll set every CPV to the same hue.
					(
						if (hueVal > 0) then newcolor.hue = hueVal
						else          		 newcolor.hue = 255 + hueVal
					)
					else							-- Otherwise we calculate relative hue changes.
					(
						if 		(oldColor.hue + hueVal > 255) then newColor.hue = oldColor.hue + hueVal - 255
						else if	(oldColor.hue + hueVal < 0)   then newColor.hue = oldColor.hue + hueVal + 255
						else 									   newColor.hue = (oldColor.hue + hueVal) as integer
					)
					
					-------------------------------------------------------------------						
					-- The Saturation and Value Calculations
					-------------------------------------------------------------------
					
					-- Calculate which of the six major hue ranges we're in.
					hueRange = floor(newColor.hue / 42.5)
					if hueRange == 6 then hueRange = 0
					
					-- Calculate the saturation.
					colorSat = case hueRange of
					(
						0: newColor.r - newColor.b
						1: newColor.g - newColor.b
						2: newColor.g - newColor.r
						3: newColor.b - newColor.r
						4: newColor.b - newColor.g
						5: newColor.r - newColor.g
					)
					
					-- Calculate the ratio between the mid - min and the saturation (To help us preserve the hue later.). 	
					midRatio = case hueRange of
					(
						0: (newColor.g - newColor.b) / colorSat
						1: (newColor.r - newColor.b) / colorSat
						2: (newColor.b - newColor.r) / colorSat
						3: (newColor.g - newColor.r) / colorSat
						4: (newColor.r - newColor.g) / colorSat
						5: (newColor.b - newColor.g) / colorSat
					)
					
					-- To find the value: First, convert the current color into it's purest hue.
					pureColor = copy newColor
					pureColor.saturation = 255
					pureColor.value      = 255
					
					-- Then, find the value of that pure color
					rVal = pureColor.r ^ 2.2
					gVal = pureColor.g ^ 2.2
					bVal = pureColor.b ^ 2.2
					
					pureHueVal = (0.227 * rVal) + (0.715 * gVal) + (0.058 * bVal)
					pureHueVal = (pureHueVal ^ 0.454545)
					pureHueVal /= 255.0
	
					-- Calculate the value (brightness) of our color.
					colorVal = case hueRange of
					(
						0: newColor.r - ((1.0 - pureHueVal) * colorSat)
						1: newColor.g - ((1.0 - pureHueVal) * colorSat)
						2: newColor.g - ((1.0 - pureHueVal) * colorSat)
						3: newColor.b - ((1.0 - pureHueVal) * colorSat)
						4: newColor.b - ((1.0 - pureHueVal) * colorSat)
						5: newColor.r - ((1.0 - pureHueVal) * colorSat)
					)
					
					-- Here we adjust the saturation.
					if colorSat > 0.0 then colorSat += satVal
					
					-- Then we check to make sure the value is valid.
					if colorSat >= 255.0 then colorSat = 255.0
					if colorSat <= 0.0   then colorSat = 0.0
					
					-- These variables are declared here to avoid scope issues.
					colorMax = 0
					colorMin = 0
					colorMid = 0
					
					-- Now we perform the value change. This is where it gets complicated.
					colorVal += valVal
					
					-- Now we'll calculate and test the max, min, and mid components of the final color.
					if colorSat == 0.0 then				-- If our color is supposed to be grey the checks are easy.
					(
						colorMax = colorVal
					
						if colorMax >= 255.0 then colorMax = 255.0
						if colorMax <= 0.0   then colorMax = 0.0
				
						colorMin = colorMax
						colorMid = colorMax	
					)
					else								-- If our color isn't grey the checks get complicated.
					(
						-- Calculation for the maximum color component.
						colorMax = colorVal + ((1.0 - pureHueVal) * colorSat)
						
						-- Range checks for the maximum color component.
						if colorMax <= 0.0 then
						(						
							colorMax = 0.0
							colorSat = 0.0
						)
						else if colorMax >= 255.0 then
						(
							maxDiff  = colorMax - 255.0
							colorMax = 255.0
							
							if maxDiff >= colorSat then
							(
								colorSat = 0.0
							)
							else
							(
								colorSat = colorSat - maxDiff
							)
						)
						
						-- Calculation for the minimum color component.
						colorMin = colorMax - colorSat
						
						-- Range checks for the minimum color component.
						if colorMin < 0.0 then
						(
							minDiff  = abs colorMin
							colorMin = 0.0
							
							if minDiff > colorSat then
							(
								colorSat = 0.0
							)
							else
							(
								colorSat = colorSat - minDiff
							)
						)
						
						-- Calculation for the middle color component.
						colorMid = colorMin + (colorSat * midRatio)
					)
	
					-- We declare the final color here to avoid scope issues.	
					newColor = (color 0 0 0)
					
					-- And the we build the final color.
					case hueRange of
					(
						0:(	-- Red to Yellow
							newColor.r = colorMax			
							newColor.b = colorMin			
							newColor.g = colorMid			
						)
						1:( -- Yellow to Green
							newColor.g = colorMax			
							newColor.b = colorMin			
							newColor.r = colorMid			
						)
						2:( -- Green to Cyan
							newColor.g = colorMax			
							newColor.r = colorMin			
							newColor.b = colorMid			
						)
						3:( -- Cyan to Blue
							newColor.b = colorMax			
							newColor.r = colorMin			
							newColor.g = colorMid			
						)
						4:( -- Blue to Magenta
							newColor.b = colorMax
							newColor.g = colorMin
							newColor.r = colorMid
						)
						5: ( -- Magenta to Red
							newColor.r = colorMax
							newColor.g = colorMin
							newColor.b = colorMid
						)
					)
	
					setvertcolor selection[i] selObjCPVs[i][j] newColor		-- Assigns the new color to the current CPV.
				)
			)
		),		
		
		
		-------------------------------------------------------------------
		-- The Brightness/Contrast change function for the BC modifier.
		-------------------------------------------------------------------	
		function bcChange selObjCPVs selObjCPVColors valAverage briVal conVal conRange =
		(
			conVal = (conRange / 100) * conval		-- Converts the 0-100 value from the contrast slider to a real value as a percentage
													-- of the contrast value range.
			iCount = selObjCPVs.count
			for i in 1 to iCount do
			(
				jCount = selObjCPVs[i].count
				for j in 1 to jCount do
				(
					oldColor = selObjCPVColors[i][j]		-- Grab the color for the current CPV.
						
					newColor = copy oldColor				-- This is the color we'll make changes to.
					
					-- Ok, first we need to figure out what the true hue-adjusted value is for the current color. We'll
					-- Then adjust the contrast of that color before we mess around with it's brightness.
					
					-- Calculate which of the six major hue ranges we're in.
					hueRange = floor(newColor.hue / 42.5)
					if hueRange == 6 then hueRange = 0
					
					-- Calculate the saturation.
					colorSat = case hueRange of
					(
						0: newColor.r - newColor.b
						1: newColor.g - newColor.b
						2: newColor.g - newColor.r
						3: newColor.b - newColor.r
						4: newColor.b - newColor.g
						5: newColor.r - newColor.g
					)
					
					-- Calculate the ratio between the mid - min and the saturation (To help us preserve the hue later.). 	
					midRatio = case hueRange of
					(
						0: (newColor.g - newColor.b) / colorSat
						1: (newColor.r - newColor.b) / colorSat
						2: (newColor.b - newColor.r) / colorSat
						3: (newColor.g - newColor.r) / colorSat
						4: (newColor.r - newColor.g) / colorSat
						5: (newColor.b - newColor.g) / colorSat
					)
					
					-- To find the value: First, convert the current color into it's purest hue.
					pureColor = copy newColor
					pureColor.saturation = 255
					pureColor.value      = 255
					
					-- Then, find the value of that pure color
					rVal = pureColor.r ^ 2.2
					gVal = pureColor.g ^ 2.2
					bVal = pureColor.b ^ 2.2
					
					pureHueVal = (0.227 * rVal) + (0.715 * gVal) + (0.058 * bVal)
					pureHueVal = (pureHueVal ^ 0.454545)
					pureHueVal /= 255.0
	
					-- Calculate the value (brightness) of our color.
					colorVal = case hueRange of
					(
						0: newColor.r - ((1.0 - pureHueVal) * colorSat)
						1: newColor.g - ((1.0 - pureHueVal) * colorSat)
						2: newColor.g - ((1.0 - pureHueVal) * colorSat)
						3: newColor.b - ((1.0 - pureHueVal) * colorSat)
						4: newColor.b - ((1.0 - pureHueVal) * colorSat)
						5: newColor.r - ((1.0 - pureHueVal) * colorSat)
					)
					
					-- Now we're ready to mess with the contrast. Which is pretty simple.
					if colorVal < valAverage then
					(
						colorVal -= conVal
						
						if colorVal > valAverage then colorVal = valAverage
						if colorVal < 0.0 then colorVal = 0.0
					)
					else if colorVal > valAverage then
					(
						colorVal += conVal
						
						if colorVal < valAverage then colorVal = valAverage
						if colorVal > 255.0 then colorVal = 255.0
					)
					
					-- And now we adjust the value. This gets complicated because very high or low values will
					-- force a change in saturation.
					colorVal += briVal
					
					-- Now we'll calculate and test the max, min, and mid components of the final color.
					if colorSat == 0.0 then				-- If our color is supposed to be grey the checks are easy.
					(
						colorMax = colorVal
					
						if colorMax >= 255.0 then colorMax = 255.0
						if colorMax <= 0.0   then colorMax = 0.0
				
						colorMin = colorMax
						colorMid = colorMax	
					)
					else								-- If our color isn't grey the checks get complicated.
					(
						-- Calculation for the maximum color component.
						colorMax = colorVal + ((1.0 - pureHueVal) * colorSat)
						
						-- Range checks for the maximum color component.
						if colorMax <= 0.0 then
						(						
							colorMax = 0.0
							colorSat = 0.0
						)
						else if colorMax >= 255.0 then
						(
							maxDiff  = colorMax - 255.0
							colorMax = 255.0
							
							if maxDiff >= colorSat then
							(
								colorSat = 0.0
							)
							else
							(
								colorSat = colorSat - maxDiff
							)
						)
						
						-- Calculation for the minimum color component.
						colorMin = colorMax - colorSat
						
						-- Range checks for the minimum color component.
						if colorMin < 0.0 then
						(
							minDiff  = abs colorMin
							colorMin = 0.0
							
							if minDiff > colorSat then
							(
								colorSat = 0.0
							)
							else
							(
								colorSat = colorSat - minDiff
							)
						)
						
						-- Calculation for the middle color component.
						colorMid = colorMin + (colorSat * midRatio)
					)
					
					-- We declare the final color here to avoid scope issues.	
					finalColor = (color 0 0 0)
					
					-- And the we build the final color.
					case hueRange of
					(
						0:(	-- Red to Yellow
							finalColor.r = colorMax			
							finalColor.b = colorMin			
							finalColor.g = colorMid			
						)
						1:( -- Yellow to Green
							finalColor.g = colorMax			
							finalColor.b = colorMin			
							finalColor.r = colorMid			
						)
						2:( -- Green to Cyan
							finalColor.g = colorMax			
							finalColor.r = colorMin			
							finalColor.b = colorMid			
						)
						3:( -- Cyan to Blue
							finalColor.b = colorMax			
							finalColor.r = colorMin			
							finalColor.g = colorMid			
				
						)
						4:( -- Blue to Magenta
							finalColor.b = colorMax
							finalColor.g = colorMin
							finalColor.r = colorMid
				
						)
						5: ( -- Magenta to Red
							finalColor.r = colorMax
							finalColor.g = colorMin
							finalColor.b = colorMid
						)
					)
	
					newColor = finalColor

					setvertcolor selection[i] selObjCPVs[i][j] newColor		-- Assigns the new color to the current CPV.
				)
			)
		),
		
		-------------------------------------------------------------------
		-- The XYZ Gradient change function for the XYZ Gradient modifier.
		-------------------------------------------------------------------	
		function xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions colorA colorB gOpacity gAxis gType gBounds =
		(
			global positionMaxVals = #()		-- Array to store all of the per-object maximum position values.
			global positionMinVals = #()		-- Array to store all of the per-object minimum position values.
				
			for i in 1 to selObjCPVPositions.count do			-- Steps through each sub-array of CPV positions stored in selObjCPVPositions.
			(
				positionMaxVals[i] = amax selObjCPVPositions[i]			
				positionMinVals[i] = amin selObjCPVPositions[i]
			)
			
			for i in 1 to selObjCPVs.count do			-- Steps through each sub-array of CPVs stored in selObjCPVs.
			(
				if (gBounds == 1) then			-- If the Gradient Bounds radio button is set too 'Entire Selection' we will store the
												-- minimum and maximum value of all the position values stored in positionMaxVals and 
												-- positionMinVals in the maxBound and minBound variables respectively. That way we get
												-- the minimum and maximum position values for all of the CPVs across all the selected
												-- objects.
				(
					maxBound = amax positionMaxVals
					minBound = amin positionMinVals
				)
				else							-- If the Gradient Bounds radio button is set to 'Per Object Selection' then we will
												-- simply copy the current object's minimum and maximum position values as stored 
												-- earlier in positionMaxVals and positionMinVals. That way our gradient will be
												-- bounded on a per-object basis instead of an overall one.
				(
					maxBound = positionMaxVals[i]
					minBound = positionMinVals[i]
				)
				
				
				
				gradRange = abs(maxBound - minBound)		
				
				for j in 1 to selObjCPVs[i].count do
				(
					gradAmt = (maxBound - selObjCPVPositions[i][j]) / gradRange
					
					if 		(gType == 1) then newColor = (colorA * (1 - gradAmt)) + (colorB * gradAmt)						-- Normal
					
					else if (gType == 2) then newColor = (colorA * (1 - gradAmt)) + (selObjCPVColors[i][j] * gradAmt)		-- A to Transparent	 
		
					else 					  newColor = (selObjCPVColors[i][j] * (1 - gradAmt)) + (colorB * gradAmt)		-- Transparent to B
		
					finalColor = (newColor * (gOpacity / 100.0)) + (selObjCPVColors[i][j] * (1 - (gOpacity / 100.0)))
					
					
					setVertColor selection[i] selObjCPVS[i][j] finalColor				
				)
			)
		)
	)
	
	--## End KVS Function Declarations.
	
	--################################################################################
	--## Here we define our tooltips for the buttons on the main KVS floater.
	--################################################################################
	
	rgb_adjust_tip   = "This modifier allows you to edit the selected object's vertex " + \
					   "colors according to their Red, Green, and Blue components."
					 
	hsv_adjust_tip   = "This modifier allows you to edit the selected object's vertex " + \
					   "colors according to their Hue, Saturation, and Value."
					 
	bc_adjust_tip    = "This modifier allows you to edit the Brightness and Contrast "  + \
					   "of the selected object's vertex colors."
					 
	xyz_gradient_tip = "This modifier allows you to apply a color gradient to the "     + \
					   "Selected objects' vertex colors along the X, Y, or Z axis."
					
	cpv_clean_tip    = "This option optimizes and rebuilds the Color-Per-Vertex "       + \
					   "Topography for the selected objects."
	
	vs_help_tip		 = "Get help on using K's VertoShop from the KVS Website."
	
	--################################################################################				 
	--## The Main VertoShop Floater
	--################################################################################
	
	floater_vertoshop = newrolloutfloater "K's VertoShop 2.0" kvsPanelWidth kvsPanelHeight 2 79		-- The floater which will hold our rollout of modifier buttons.
	
	max modify mode			-- If the modifier panel isn't active, then sometimes the modifier buttons stay greyed 
							-- out when they shouldn't. To avoid confusing the user we'll just switch to it now.
							
	rollout rollModifiers "Vertex Color Modifiers"			-- Our modifier rollout.
	(
	
		-------------------------------------------------------------------
		-- The UI declarations for the main KVS floater.
		-------------------------------------------------------------------
		group "Modifiers"
		(
			button btn_rgb_adjust	 "Red/Green/Blue"	   		width:128  height:22  	tooltip:rgb_adjust_tip		-- Button for the RGB modifier.
			button btn_hsv_adjust 	 "Hue/Saturation/Value" 	width:128  height:22	tooltip:hsv_adjust_tip		-- Button for the HSV modifier.
			button btn_bc_adjust 	 "Brightness/Contrast"  	width:128  height:22	tooltip:bc_adjust_tip		-- Button for the Contrast modifier.
			button btn_xyz_gradient	 "XYZ Gradient"		   		width:128  height:22	tooltip:xyz_gradient_tip	-- Button for the XYZ gradient modifier.
			button btn_DotShade      "Dot Shade"				width:128  height:22    enabled:false
			button btn_ApplyLighting "Apply Lighting"			width:128  height:22	enabled:false
		)
		
		group "Vertex Selection Options"
		(
			checkbox mask_verts "Mask to Selected Polys" 		-- Checkbox to enable/disable the option to mask the vertex selection to the
																-- selected polys. This option lets us create hard edged color changes along
															 	-- poly edges. Which is useful when you're simulating hard shadows.
		)
		
		group "CPV Utilities"
		(
			button cpv_clean  "Rebuild Object CPVs"	width:128 height:22 tooltip:cpv_clean_tip		-- Button for the CPV rebuild modifier.
		)	
				
		timer vs_timer interval:250			-- A timer that we'll use to check whether each button should be enabled or not.	
			
		-------------------------------------------------------------------	
		-- The Timer Event
		-------------------------------------------------------------------
		on vs_timer tick do
		(
			meshchk = kvs.checkForMeshes()		-- Runs the kvs.checkForMeshes function to see if any editable meshes are selected.
			
			faceSelCount = kvs.getSelObjSelFaces() 
			
			-- Later on we'll need to know whether any of the selected meshes have any polys selected. This
			-- is so we know whether to enable the mask_verts checkbox or not. So, if editble meshes were found, 
			-- this next statement runs the kvs.checkForPolySel() function and sets the polyselchk variable to true 
			-- if poly selections were found and sets it to false if no poly selections were found. The else  
			-- clause sets it to false if there were no editable meshes found to start with.
			
			if (meshchk == true) then polyselchk = kvs.checkForPolySel() else polyselchk = false
	
			if (selection.count == 0) or (meshchk == false) then	-- If nothing is selected (or no editable meshes are selected) we'll
																	-- disable all the modifier buttons to prevent problems. (I'm using 
																	-- if/then statements here instead of simple assignments so that the
																	-- interface buttons won't flicker from being constantly enabled.)
			(
				if (mask_verts.enabled       == true) then mask_verts.enabled       = false
				if (btn_rgb_adjust.enabled   == true) then btn_rgb_adjust.enabled   = false
				if (btn_hsv_adjust.enabled   == true) then btn_hsv_adjust.enabled   = false
				if (btn_bc_adjust.enabled   == true)  then btn_bc_adjust.enabled   = false
				if (btn_xyz_gradient.enabled == true) then btn_xyz_gradient.enabled = false
				if (cpv_clean.enabled        == true) then cpv_clean.enabled        = false
			)
	
			else if (subobjectlevel == 1) and (faceSelCount == 0) then		-- If we're in vert edit mode and no faces are selected, then all  
																			-- buttons *except for* the masking checkbox will be enabled. 
			(
				if (mask_verts.enabled       == true)  then mask_verts.enabled       = false
				if (btn_rgb_adjust.enabled   == false) then btn_rgb_adjust.enabled   = true
				if (btn_hsv_adjust.enabled   == false) then btn_hsv_adjust.enabled   = true
				if (btn_bc_adjust.enabled   == false)  then btn_bc_adjust.enabled   = true
				if (btn_xyz_gradient.enabled == false) then btn_xyz_gradient.enabled = true
				if (cpv_clean.enabled        == true)  then cpv_clean.enabled        = false
			)
			
			else if (subobjectlevel == 1) and (faceSelCount != 0) then		-- If we're in vert edit mode and no faces are selected, then all  
																			-- buttons *including* the masking checkbox will be enabled. 
			(
				if (mask_verts.enabled       == false) then mask_verts.enabled       = true
				if (btn_rgb_adjust.enabled   == false) then btn_rgb_adjust.enabled   = true
				if (btn_hsv_adjust.enabled   == false) then btn_hsv_adjust.enabled   = true
				if (btn_bc_adjust.enabled   == false)  then btn_bc_adjust.enabled   = true
				if (btn_xyz_gradient.enabled == false) then btn_xyz_gradient.enabled = true
				if (cpv_clean.enabled        == true)  then cpv_clean.enabled        = false
			)
			
			else if (subobjectlevel == 0) then		-- If we're in object edit mode then every item will be enabled except for the masking checkbox.
			(
				if (mask_verts.enabled       == true)  then mask_verts.enabled       = false
				if (btn_rgb_adjust.enabled   == false) then btn_rgb_adjust.enabled   = true
				if (btn_hsv_adjust.enabled   == false) then btn_hsv_adjust.enabled   = true
				if (btn_bc_adjust.enabled   == false)  then btn_bc_adjust.enabled   = true
				if (btn_xyz_gradient.enabled == false) then btn_xyz_gradient.enabled = true
				if (cpv_clean.enabled        == false) then cpv_clean.enabled        = true
			)
			
			else if (subobjectlevel == 2) then		-- If we're in edge edit mode then every button will be disabled.
			(
				if (mask_verts.enabled       == true)  then mask_verts.enabled       = false
				if (btn_rgb_adjust.enabled   == true)  then btn_rgb_adjust.enabled   = false
				if (btn_hsv_adjust.enabled   == true)  then btn_hsv_adjust.enabled   = false
				if (btn_bc_adjust.enabled   == true)   then btn_bc_adjust.enabled   = false
				if (btn_xyz_gradient.enabled == true)  then btn_xyz_gradient.enabled = false
				if (cpv_clean.enabled        == true)  then cpv_clean.enabled        = false
			)
			
			else if (subobjectlevel == 3) \
				 or (subobjectlevel == 4) \
				 or (subobjectlevel == 5) then      -- If we're in one of the other selection modes that generate a face selection, then 
													-- the masking checkbox will be disabled while the modifier buttons will be enabled.
			(			
				if (mask_verts.enabled       == true)  then mask_verts.enabled       = false
				if (btn_rgb_adjust.enabled   == false) then btn_rgb_adjust.enabled   = true
				if (btn_hsv_adjust.enabled   == false) then btn_hsv_adjust.enabled   = true
				if (btn_bc_adjust.enabled   == false)  then btn_bc_adjust.enabled   = true
				if (btn_xyz_gradient.enabled == false) then btn_xyz_gradient.enabled = true
				if (cpv_clean.enabled        == true)  then cpv_clean.enabled        = false
			)		
		)
		
		-------------------------------------------------------------------
		-- The Red/Green/Blue Modifier Event.
		-------------------------------------------------------------------
		on btn_rgb_adjust pressed do
		(
			rollModifiers.vs_timer.active = false		-- Turns off the timer event so that it doesn't slow us down
														-- or cause other problems while it isn't needed.
		
			-- The following statements will disable the modifier buttons on the main KVS floater so that the
			-- user cannot call more than one modifier at a time. The rollout exit event will turn the timer
			-- back on which will automatically turn the appropriate modifier buttons back on as well.
		
			rollModifiers.mask_verts.enabled   		= false
			rollModifiers.btn_rgb_adjust.enabled   	= false
			rollModifiers.btn_hsv_adjust.enabled   	= false
			rollModifiers.btn_bc_adjust.enabled   	= false
			rollModifiers.btn_xyz_gradient.enabled 	= false
			rollModifiers.cpv_clean.enabled        	= false
			
			max modify mode		-- Makes sure the modify panel is active so that the subobject calls work.
			
			select (kvs.nonMeshSelCull())		-- Calls the kvs.nonMeshSelCull function to drop any non-mesh objects from the selection.
			
			flagforeground selection true		-- Increases redraw speed by bringing the selected objects to the foreground plane.
			
			global initSelection = selection as array		-- Stores the current selection as an array so that we can catch and prevent
															-- the user from changing the selection while the modifier panel is still open.
			
			global rollProgress = kvs.prepProgFloater()		-- Now, on small numbers of objects the following calculations will finish 
															-- quickly and HSV interface will pop up without much delay. But with large 
															-- numbers of objects the prep time may end up being quite long. So we'll 
															-- use the prepProgFloater function to create a floater with a progress bar 
															-- and variable text label. We can then update the floater as we prep the 
															-- objects so the user doesn't think the script has crashed. 
			
			global editMeshflag = false			-- If our user has selected faces and verts across multiple objects then we
												-- will need to throw an edit mesh across all the selected objects once the
												-- vertex color modifications are complete so that we can display their 
												-- selection as it was before the modifier was run. This is done because 
												-- scripted CPV modifications cannot be performed on meshes which have any
												-- modifiers applied to them.
	
			global selSubObjectLevel = subobjectlevel		-- Stores the pre-modifier sub-object level so that we can return to it later.
	
			if (selection.count > 1) and (selSubObjectLevel != 0) then				-- So if there's more than one object selected and the subobjectmode is not '0'...
			(
				editMeshFlag = true			-- Then we set the edit mesh flag to true.
			)
			
			global selObjCPVs = kvs.buildObjCPVlist rollProgress selSubObjectLevel  mask_verts.checked			-- Now we need to pre-process the selected objects to make sure 
																												-- they have CPV topologies and to build the list of selected 
																												-- object CPVs which will be passed to the HSV modifier. The 
																												-- rollProgress variable is being passed so that the
																												-- kvs.buildObjCPVlist can modify the progress bar rollout. Scope 
																												-- issues would not permit this otherwise.
			
			badObjCount = kvs.countCPVLessObjs selObjCPVs			-- Calls the kvs.countCPVLessObjs to count the number of objects that have no CPVs defined. A
																	-- non-zero count here will indicate that some objects do not have a vertex or face selected. Or
																	-- (when using vertex masking) objects whose vertex and face selections do not overlap. In any
																	-- case, we want to be able to catch those objects so that we don't crash the modifier by passing
																	-- it undefined data.
			
			if (badObjCount > 0) then			-- So if badObjCount is not zero, then we have 1 or more objects without CPV selections. We
												-- therefore need to throw up an error message instead of running the modifier and letting it
												-- crash the script. The if statements that follow will be used to nail down exactly which
												-- error message we show the user.
			(
				if (selSubObjectLevel == 1) and (rollmodifiers.mask_verts.state == false)then
				(
					if (badObjCount == 1) then
					(
						messagebox ("1 selected object has no selected verts. You must select at least one vertex from each selected object.") \
							Title:"Vertex Selection Error"
					)
					else
					(
						messagebox (badObjCount as string + " selected objects have no selected verts. You must select at least one vertex from each selected object.") \
							Title:"Vertex Selection Error"
					)
				
				)
				else if (selSubObjectLevel == 1) and (rollmodifiers.mask_verts.state == true)then
				(
					messagebox ("The vertex and face selections for " + badObjCount as string + " object(s) do not overlap.") Title:"Vertex Masking Error"
				)
				else
				(
					if (badObjCount == 1) then
					(
						messagebox ("1 selected object has no selected faces. You must select at least one face from each selected object.") \
							Title:"Face Selection Error"
					)
					else
					(
						messagebox (badObjCount as string + " selected objects have no selected faces. You must select at least one face from each selected object.") \
							Title:"Face Selection Error"
					)		
				)
				
				-- Now that we've thrown up the error message and aborted running the modifier we need to close the
				-- progress bar, return the selected objects to the background plane, and return to whatever subobject 
				-- mode we started in.
				
				closeRolloutfloater progFloater			-- Closes the progress bar rollout.
				
				if (editMeshFlag == true) then			-- If the user invoked the modifier using a face or vertex selection made across
														-- multiple objects using an edit mesh modifier, then we want to return to the same
														-- state we were in before collapsing the stacks, etc. So if the edit mesh flag was
														-- set at the beginning of this event...
				(
					addmodifier selection (edit_mesh ())		-- We add an edit mesh modifier to the selection.
					
					subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
				)
				else 
				(
					subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
				)
								
				flagforeground selection false		-- Returns the selected objects to the background plane.
				
				rollModifiers.vs_timer.active = true			-- Turns the timer event back on.
			)
			else				-- If no objects had 0 CPV values stored, then we go ahead and run the 
								-- modifier. Since we're not in danger of crashing the script.
			(		
				for i in 1 to selObjCPVs.count do			-- Here we convert all of the bitarrays stored in selObjCPVs to ordinary arrays 
															-- Bitarrays are fast and memory efficient, but we want to be able to index
															-- the CPVs and the colors for those CPVs in the same way so there's no problems
															-- down the line. 
				(
					selObjCPVs[i] = selObjCPVs[i] as array
				)
						
				global selObjCPVColors = kvs.buildObjCPVColorlist selObjCPVs rollProgress		-- Now we need to take the array of CPV arrays we generated with the 
																								-- kvs.buildObjCPVlist function and build a corresponding array of 
																								-- colors for the CPVs we'll be working with. The kvs.buildObjCPVColorlist
																								-- will do this for us. Again, we have to pass the rollProgress variable
																								-- so that the function can modify the progress bar rollout.
																						
				closeRolloutfloater progFloater		-- Closes the progress bar rollout.
				
				-- RGB Modifier is called here.
				
				global floatRGB = newrolloutfloater "K's VertoShop" rgbPanelWidth rgbPanelHeight 700 630		-- Defines the floater for the HSV rollout.
				
				rollout rollRGB "Red/Green/Blue"
				(
					-- Button and Slider Declarations.
					
					-- The Red slider and spinner.
					
					slider		sldRed 			"Red" 				pos:[15,16] 	width:375 	height:44 	range:[-256,256,0] 	type:#integer 	ticks:2
					spinner		spinRed			""					pos:[334,15]  	width:48 	height:18	range:[-256,256,0]	type:#integer
					
					-- The Green slider and spinner.	
				
					slider 		sldGreen 		"Green" 			pos:[15,73] 	width:375 	height:44 	range:[-256,256,0] 	type:#integer 	ticks:2
					spinner 	spinGreen 		"" 					pos:[334,72]  	width:48 	height:18	range:[-256,256,0]	type:#integer
						

					-- The Blue slider and spinner.
				
					slider 		sldBlue 		"Blue" 				pos:[15,128] 	width:375 	height:44 	range:[-256,256,0] 	type:#integer 	ticks:2
					spinner 	spinBlue 		"" 					pos:[334,127] 	width:48 	height:18	range:[-256,256,0]	type:#integer
				
					-- the OK, Reset, and Cancel Buttons.
				
					button		btnOK			"OK"				pos:[413,14] 	width:75 	height:25
					button 		btnReset 		"Reset" 			pos:[413,42] 	width:75 	height:25
					button		btnCancel		"Cancel"			pos:[413,70] 	width:75 	height:25
				
					-- A couple of option checkboxes.
				
					checkbox	cbxRealtime		"Realtime Update" 		pos:[400,170]	checked:true		-- This checkbox will be used to toggle between the realtime
																											-- and update-on-mouseup viewport update modes.
					-- A timer that we'll use to make sure the user doesn't change the current selection.										
																	
					timer 	selTimer 	interval:250			-- A timer that we'll use to check whether each button should be enabled or not.
					

					-- The timer event.
					
					on selTimer tick do	
					(
						curSel = selection as array
					
						if initSelection as string != curSel as string then select initSelection
					)
																								
					-- The Red slider and spinner events.
																							
					on sldRed changed foo do
					(
						spinRed.value = sldRed.value		-- Sets the Hue spinner value to the value of the Hue slider.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																														-- the CPV colors of the selected objects.
			
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on sldRed buttonup do
					(
						kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																													-- the CPV colors of the selected objects.
				
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on spinRed changed foo do
					(
						sldRed.value = spinRed.value		-- Sets the Hue slider value to the value of the Hue spinner.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																														-- the CPV colors of the selected objects.
			
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on spinRed buttonup do
					(
						kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																													-- the CPV colors of the selected objects.
				
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					-- The Green slider and spinner events.
					
					on sldGreen changed foo do
					(
						spinGreen.value = sldGreen.value		-- Sets the Saturation spinner value to the value of the Saturation slider.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																														-- the CPV colors of the selected objects.
			
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on sldGreen buttonup do
					(
						kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																													-- the CPV colors of the selected objects.
				
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on spinGreen changed foo do
					(
						sldGreen.value = spinGreen.value		-- Sets the Saturation slider value to the value of the Saturation spinner.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																														-- the CPV colors of the selected objects.
			
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on spinGreen buttonup do
					(
						kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																													-- the CPV colors of the selected objects.
				
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
		
					-- The Blue slider and spinner events.
					
					on sldBlue changed foo do
					(
						spinBlue.value = sldBlue.value		-- Sets the Value spinner value to the value of the Value slider.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																														-- the CPV colors of the selected objects.
			
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on sldBlue buttonup do
					(
						kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																													-- the CPV colors of the selected objects.
				
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on spinBlue changed foo do
					(
						sldBlue.value = spinBlue.Value		-- Sets the Value slider value to the value of the Value spinner.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																														-- the CPV colors of the selected objects.
			
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on spinBlue buttonup do
					(
						kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																													-- the CPV colors of the selected objects.
				
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
		
					-- The OK, Reset, and Cancel button events.
				
					on btnOK pressed do			-- When the OK button is pressed...
					(
						closerolloutfloater floatRGB		-- We close the HSV floater. This will also trigger everything contained in the
															-- Close event defined below. This includes cleaning up the object CPVs.
					)
					
					on btnReset pressed do
					(
						-- First we reset all of the sliders, spinners, and checkboxes to their default states.
					
						sldRed.value  = 0
						spinRed.value = 0
						
						sldGreen.value  = 0
						spinGreen.value = 0
						
						sldBlue.value  = 0
						spinBlue.value = 0
						
						-- Then we process the selected objects to reflect the change.
						
						kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																													-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on btnCancel pressed do
					(
						-- First we reset all of the sliders, spinners, and checkboxes to their default states.
					
						sldRed.value  = 0
						spinRed.value = 0
						
						sldGreen.value  = 0
						spinGreen.value = 0
						
						sldBlue.value  = 0
						spinBlue.value = 0
										
						-- Then we process the selected objects to reflect the change.
						
						kvs.rgbChange selObjCPVs selObjCPVColors sldRed.value sldGreen.value sldBlue.value  		-- Calls the kvs.rgbChange function to process 
																													-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						
						closerolloutfloater floatRGB		-- We close the HSV floater. This will also trigger everything contained in the
															-- okToClose event defined below. This includes cleaning up the object CPVs.
					)
					
					on rollRGB close do			-- This event will be called when the rollout is closed. Either by the user clicking the
												-- closebox on the floater window, or when the OK or Cancel event close the floater.
					(
						-- Then we clean up the CPV topologies for the objects just manipulated.
						
						rollProgress = kvs.cleanProgFloater()		-- Uses the cleanProgFloater function to pop up a floater with a progress
																	-- bar and variable text label on it so that the user can watch something 
																	-- while the cleanup routines are executing. Otherwise with large selections
																	-- the user might assume the script has crashed and kill Max.
						
						for i in 1 to selection.count do			-- Steps through all the selected objects.
						(
							rollProgress.workingon.text = ("Cleaning up: " + selection[i].name as string + "...")		-- Updates the workingon label in the progress rollout with

																														-- the name of the current object.
						
							if (classof selection[i] == editable_mesh) then			-- If the current object is an editable mesh...
							(
								kvs.cleancpvs selection[i]				-- We run the kvs.cleancpvs function on it to clean up it's CPV topography
																		-- so everything is nice and neat and efficient.
																	
								rollProgress.progress.value = (100 / selection.count) * i			-- Updates the cleanup progress bar.
							)
							else			-- If the current object is not an editable mesh...
							(
								rollProgress.progress.value = (100 / selection.count) * i			-- We just update the cleanup progress bar.
							)
						) 
						
						rollProgress.workingon.text = "Finishing up..."			-- Updates the workingon label text.
						
						closerolloutfloater progFloater			-- Closes the progress bar floater.
						
						if (editMeshFlag == true) then			-- If the user invoked the modifier using a face or vertex selection made across
																-- multiple objects using an edit mesh modifier, then we want to return to the same
																-- state we were in before collapsing the stacks, etc. So if the edit mesh flag was
																-- set at the beginning of this event...
						(
							addmodifier selection (edit_mesh ())		-- We add an edit mesh modifier to the selection.
							
							subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
						)
						else 
						(
							subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
						)
										
						flagforeground selection false		-- Returns the selected objects to the background plane.
						
						rollModifiers.vs_timer.active = true			-- Turns the timer event back on.
					)
				)
				addrollout rollRGB floatRGB			-- Adds the HSV rollout to the HSV floater.
			)	
		)
		
		-------------------------------------------------------------------
		-- The Hue/Saturation/Value Modifier Event.
		-------------------------------------------------------------------
		on btn_hsv_adjust pressed do
		(
			rollModifiers.vs_timer.active = false		-- Turns off the timer event so that it doesn't slow us down
														-- or cause other problems while it isn't needed.
														
			-- The following statements will disable the modifier buttons on the main KVS floater so that the
			-- user cannot call more than one modifier at a time. The rollout exit event will turn the timer
			-- back on which will automatically turn the appropriate modifier buttons back on as well.
		
			rollModifiers.mask_verts.enabled   		= false
			rollModifiers.btn_rgb_adjust.enabled   	= false
			rollModifiers.btn_hsv_adjust.enabled   	= false
			rollModifiers.btn_bc_adjust.enabled   	= false
			rollModifiers.btn_xyz_gradient.enabled 	= false
			rollModifiers.cpv_clean.enabled        	= false
		
			max modify mode		-- Makes sure the modify panel is active so that the subobject calls work.
			
			select (kvs.nonMeshSelCull())		-- Calls the kvs.nonMeshSelCull function to drop any non-mesh objects from the selection.
			
			flagforeground selection true		-- Increases redraw speed by bringing the selected objects to the foreground plane.
			
			global initSelection = selection as array		-- Stores the current selection as an array so that we can catch and prevent
															-- the user from changing the selection while the modifier panel is still open.
			
			global rollProgress = kvs.prepProgFloater()		-- Now, on small numbers of objects the following calculations will finish 
															-- quickly and HSV interface will pop up without much delay. But with large 
															-- numbers of objects the prep time may end up being quite long. So we'll 
															-- use the prepProgFloater function to create a floater with a progress bar 
															-- and variable text label. We can then update the floater as we prep the 
															-- objects so the user doesn't think the script has crashed. 
			
			global editMeshflag = false			-- If our user has selected faces and verts across multiple objects then we
												-- will need to throw an edit mesh across all the selected objects once the
												-- vertex color modifications are complete so that we can display their 
												-- selection as it was before the modifier was run. This is done because 
												-- scripted CPV modifications cannot be performed on meshes which have any
												-- modifiers applied to them.
	
			global selSubObjectLevel = subobjectlevel		-- Stores the pre-modifier sub-object level so that we can return to it later.
	
			if (selection.count > 1) and (selSubObjectLevel != 0) then				-- So if there's more than one object selected and the subobjectmode is not '0'...
			(
				editMeshFlag = true			-- Then we set the edit mesh flag to true.
			)
			
			global selObjCPVs = kvs.buildObjCPVlist rollProgress selSubObjectLevel  mask_verts.checked			-- Now we need to pre-process the selected objects to make sure 
																												-- they have CPV topologies and to build the list of selected 
																												-- object CPVs which will be passed to the HSV modifier. The 
																												-- rollProgress variable is being passed so that the
																												-- kvs.buildObjCPVlist can modify the progress bar rollout. Scope 
																												-- issues would not permit this otherwise.
			
			badObjCount = kvs.countCPVLessObjs selObjCPVs			-- Calls the kvs.countCPVLessObjs to count the number of objects that have no CPVs defined. A
																	-- non-zero count here will indicate that some objects do not have a vertex or face selected. Or
																	-- (when using vertex masking) objects whose vertex and face selections do not overlap. In any
																	-- case, we want to be able to catch those objects so that we don't crash the modifier by passing
																	-- it undefined data.
			
			if (badObjCount > 0) then			-- So if badObjCount is not zero, then we have 1 or more objects without CPV selections. We
												-- therefore need to throw up an error message instead of running the modifier and letting it
												-- crash the script. The if statements that follow will be used to nail down exactly which
												-- error message we show the user.
			(
				if (selSubObjectLevel == 1) and (rollmodifiers.mask_verts.state == false)then
				(
					if (badObjCount == 1) then
					(
						messagebox ("1 selected object has no selected verts. You must select at least one vertex from each selected object.") \
							Title:"Vertex Selection Error"
					)
					else
					(
						messagebox (badObjCount as string + " selected objects have no selected verts. You must select at least one vertex from each selected object.") \
							Title:"Vertex Selection Error"
					)
				
				)
				else if (selSubObjectLevel == 1) and (rollmodifiers.mask_verts.state == true)then
				(
					messagebox ("The vertex and face selections for " + badObjCount as string + " object(s) do not overlap.") Title:"Vertex Masking Error"
				)
				else
				(
					if (badObjCount == 1) then
					(
						messagebox ("1 selected object has no selected faces. You must select at least one face from each selected object.") \
							Title:"Face Selection Error"
					)
					else
					(
						messagebox (badObjCount as string + " selected objects have no selected faces. You must select at least one face from each selected object.") \
							Title:"Face Selection Error"
					)		
				)
				
				-- Now that we've thrown up the error message and aborted running the modifier we need to close the
				-- progress bar, return the selected objects to the background plane, and return to whatever subobject 
				-- mode we started in.
				
				closeRolloutfloater progFloater			-- Closes the progress bar rollout.
				
				if (editMeshFlag == true) then			-- If the user invoked the modifier using a face or vertex selection made across
														-- multiple objects using an edit mesh modifier, then we want to return to the same
														-- state we were in before collapsing the stacks, etc. So if the edit mesh flag was
														-- set at the beginning of this event...
				(
					addmodifier selection (edit_mesh ())		-- We add an edit mesh modifier to the selection.
					
					subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
				)
				else 
				(
					subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
				)
								
				flagforeground selection false		-- Returns the selected objects to the background plane.
				
				rollModifiers.vs_timer.active = true			-- Turns the timer event back on.
			)
			else				-- If no objects had 0 CPV values stored, then we go ahead and run the 
								-- modifier. Since we're not in danger of crashing the script.
			(		
				for i in 1 to selObjCPVs.count do			-- Here we convert all of the bitarrays stored in selObjCPVs to ordinary arrays 
															-- Bitarrays are fast and memory efficient, but we want to be able to index
															-- the CPVs and the colors for those CPVs in the same way so there's no problems
															-- down the line. 
				(
					selObjCPVs[i] = selObjCPVs[i] as array
				)
						
				global selObjCPVColors = kvs.buildObjCPVColorlist selObjCPVs rollProgress		-- Now we need to take the array of CPV arrays we generated with the 
																								-- kvs.buildObjCPVlist function and build a corresponding array of 
																								-- colors for the CPVs we'll be working with. The kvs.buildObjCPVColorlist
																								-- will do this for us. Again, we have to pass the rollProgress variable
																								-- so that the function can modify the progress bar rollout.
																						
				closeRolloutfloater progFloater		-- Closes the progress bar rollout.
				
				-- HSV modifier is called here. 
				
				global floatHSV = newrolloutfloater "K's VertoShop" hsvPanelWidth hsvPanelHeight 700 630		-- Defines the floater for the HSV rollout.
				
				rollout rollHSV "Hue/Saturation/Value"
				(
					-- Button and Slider Declarations.
					
					-- The Hue slider and spinner.
					
					slider		sldHue 			"Hue" 				pos:[15,16] 	width:375 	height:44 	range:[-128,128,0] 	type:#integer 	ticks:2
					spinner		spinHue			""					pos:[334,15]  	width:48 	height:18	range:[-128,128,0]	type:#integer
					
					-- The Saturation slider and spinner.	
				
					slider 		sldSat 			"Saturation" 		pos:[15,73] 	width:375 	height:44 	range:[-255,255,0] 	type:#integer 	ticks:2
					spinner 	spinSat 		"" 					pos:[334,72]  	width:48 	height:18	range:[-255,255,0]	type:#integer
						
					-- The Value slider and spinner.
				
					slider 		sldVal 			"Value" 			pos:[15,128] 	width:375 	height:44 	range:[-255,255,0] 	type:#integer 	ticks:2
					spinner 	spinVal 		"" 					pos:[334,127] 	width:48 	height:18	range:[-255,255,0]	type:#integer
				
					-- the OK, Reset, and Cancel Buttons.
				
					button		btnOK			"OK"				pos:[413,14] 	width:75 	height:25
					button 		btnReset 		"Reset" 			pos:[413,42] 	width:75 	height:25
					button		btnCancel		"Cancel"			pos:[413,70] 	width:75 	height:25
				
					-- A couple of option checkboxes.
				
					checkbox	cbxMergeHues	"Merge Hues"			pos:[400,150]	checked:false		-- This checkbox will toggle the merged hue mode. An effect which
																											-- is modeled after the 'colorize' option from Photoshop's HSV modifier.
				
					checkbox	cbxRealtime		"Realtime Update" 		pos:[400,170]	checked:true		-- This checkbox will be used to toggle between the realtime
																											-- and update-on-mouseup viewport update modes.
					-- A timer that we'll use to make sure the user doesn't change the current selection.										
																	
					timer 	selTimer 	interval:250			-- A timer that we'll use to check whether each button should be enabled or not.
					
					-- The timer event.
					
					on selTimer tick do	
					(
						curSel = selection as array
					
						if initSelection as string != curSel as string then select initSelection
					)			
					
					-- The Hue slider and spinner events.
																							
					on sldHue changed foo do
					(
						spinHue.value = sldHue.value		-- Sets the Hue spinner value to the value of the Hue slider.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																		-- the CPV colors of the selected objects.
			
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on sldHue buttonup do
					(
						kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																	-- the CPV colors of the selected objects.
			
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on spinHue changed foo do
					(
						sldHue.value = spinHue.value		-- Sets the Hue slider value to the value of the Hue spinner.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the spinner moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																		-- the CPV colors of the selected objects.
																			
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on spinHue buttonup do
					(
						kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																	-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					-- The Saturation slider and spinner events.
					
					on sldSat changed foo do
					(
						spinSat.value = sldSat.value		-- Sets the Saturation spinner value to the value of the Saturation slider.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																		-- the CPV colors of the selected objects.
		
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on sldSat buttonup do
					(
						kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																	-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on spinSat changed foo do
					(
						sldSat.value = spinSat.value		-- Sets the Saturation slider value to the value of the Saturation spinner.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the spinner moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																		-- the CPV colors of the selected objects.
		
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on spinSat buttonup do
					(
						kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																	-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
		
					-- The Value slider and spinner events.
					
					on sldVal changed foo do
					(
						spinVal.value = sldVal.value		-- Sets the Value spinner value to the value of the Value slider.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																		-- the CPV colors of the selected objects.
		
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on sldVal buttonup do
					(
						kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																	-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on spinVal changed foo do
					(
						sldVal.value = spinVal.Value		-- Sets the Value slider value to the value of the Value spinner.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the spinner moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event. 
						(
							kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																		-- the CPV colors of the selected objects.
		
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on spinVal buttonup do
					(
						kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																	-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
				
					-- The checkbox events.
					
					on cbxMergeHues changed foo do
					(
						kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																	-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)		
				
					-- The OK, Reset, and Cancel button events.
				
					on btnOK pressed do			-- When the OK button is pressed...
					(
						closerolloutfloater floatHSV		-- We close the HSV floater. This will also trigger everything contained in the
															-- Close event defined below. This includes cleaning up the object CPVs.
					)
					
					on btnReset pressed do
					(
						-- First we reset all of the sliders, spinners, and checkboxes to their default states.
					
						sldHue.value  = 0
						spinHue.value = 0
						
						sldSat.value  = 0
						spinSat.value = 0
						
						sldVal.value  = 0
						spinVal.value = 0
						
						cbxMergeHues.checked = false
										
						-- Then we process the selected objects to reflect the change.
						
						kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																	-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on btnCancel pressed do
					(
						-- First we reset all of the sliders, spinners, and checkboxes to their default states.
					
						sldHue.value  = 0
						spinHue.value = 0
						
						sldSat.value  = 0
						spinSat.value = 0
						
						sldVal.value  = 0
						spinVal.value = 0
						
						cbxMergeHues.checked = false
										
						-- Then we process the selected objects to reflect the change.
						
						kvs.hsvChange selObjCPVs selObjCPVColors sldHue.value sldSat.value sldVal.value cbxMergeHues.checked 		-- Calls the kvs.hsvChange function to process 
																																	-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						
						closerolloutfloater floatHSV		-- We close the HSV floater. This will also trigger everything contained in the
															-- okToClose event defined below. This includes cleaning up the object CPVs.
					)
					
					on rollHSV close do			-- This event will be called when the rollout is closed. Either by the user clicking the
												-- closebox on the floater window, or when the OK or Cancel event close the floater.
					(
						-- Then we clean up the CPV topologies for the objects just manipulated.
						
						rollProgress = kvs.cleanProgFloater()		-- Uses the cleanProgFloater function to pop up a floater with a progress
																	-- bar and variable text label on it so that the user can watch something 
																	-- while the cleanup routines are executing. Otherwise with large selections
																	-- the user might assume the script has crashed and kill Max.
						
						for i in 1 to selection.count do			-- Steps through all the selected objects.
						(
							rollProgress.workingon.text = ("Cleaning up: " + selection[i].name as string + "...")		-- Updates the workingon label in the progress rollout with
																														-- the name of the current object.
						
							if (classof selection[i] == editable_mesh) then			-- If the current object is an editable mesh...
							(
							kvs.cleancpvs selection[i]				-- We run the kvs.cleancpvs function on it to clean up it's CPV topography
																	-- so everything is nice and neat and efficient.
																	
								rollProgress.progress.value = (100 / selection.count) * i			-- Updates the cleanup progress bar.
							)
							else			-- If the current object is not an editable mesh...
							(
								rollProgress.progress.value = (100 / selection.count) * i			-- We just update the cleanup progress bar.
							)
						) 
						
						rollProgress.workingon.text = "Finishing up..."			-- Updates the workingon label text.
						
						closerolloutfloater progFloater			-- Closes the progress bar floater.
						
						if (editMeshFlag == true) then			-- If the user invoked the modifier using a face or vertex selection made across
																-- multiple objects using an edit mesh modifier, then we want to return to the same
																-- state we were in before collapsing the stacks, etc. So if the edit mesh flag was
																-- set at the beginning of this event...
						(
							addmodifier selection (edit_mesh ())		-- We add an edit mesh modifier to the selection.
							
							subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
						)
						else 
						(
							subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
						)
										
						flagforeground selection false		-- Returns the selected objects to the background plane.
						
						rollModifiers.vs_timer.active = true			-- Turns the timer event back on.
					)	
				)	
				addrollout rollHSV floatHSV			-- Adds the HSV rollout to the HSV floater.
			)
		)
		
		-------------------------------------------------------------------
		-- The Contrast Modifier Event.
		-------------------------------------------------------------------
		on btn_bc_adjust pressed do
		(
			rollModifiers.vs_timer.active = false		-- Turns off the timer event so that it doesn't slow us down
														-- or cause other problems while it isn't needed.
														
			-- The following statements will disable the modifier buttons on the main KVS floater so that the
			-- user cannot call more than one modifier at a time. The rollout exit event will turn the timer
			-- back on which will automatically turn the appropriate modifier buttons back on as well.
		
			rollModifiers.mask_verts.enabled   		= false
			rollModifiers.btn_rgb_adjust.enabled   	= false
			rollModifiers.btn_hsv_adjust.enabled   	= false
			rollModifiers.btn_bc_adjust.enabled   	= false
			rollModifiers.btn_xyz_gradient.enabled 	= false
			rollModifiers.cpv_clean.enabled        	= false
		
			max modify mode		-- Makes sure the modify panel is active so that the subobject calls work.
			
			select (kvs.nonMeshSelCull())		-- Calls the kvs.nonMeshSelCull function to drop any non-mesh objects from the selection.
			
			flagforeground selection true		-- Increases redraw speed by bringing the selected objects to the foreground plane.
			
			global initSelection = selection as array		-- Stores the current selection as an array so that we can catch and prevent
															-- the user from changing the selection while the modifier panel is still open.
			
			global rollProgress = kvs.prepProgFloater()			-- Now, on small numbers of objects the following calculations will finish 
																-- quickly and the Contrast interface will pop up without much delay. But  
																-- with large numbers of objects the prep time may end up being quite long.  
																-- So we'll use the prepProgFloater function to create a floater with a 
																-- progress bar and variable text label. We can then update the floater as  
																-- we prep the objects so the user doesn't think the script has crashed. 
			
			global editMeshflag = false			-- If our user has selected faces and verts across multiple objects then we
												-- will need to throw an edit mesh across all the selected objects once the
												-- vertex color modifications are complete so that we can display their 
												-- selection as it was before the modifier was run. This is done because 
												-- scripted CPV modifications cannot be performed on meshes which have any
												-- modifiers applied to them.
	
			global selSubObjectLevel = subobjectlevel		-- Stores the pre-modifier sub-object level so that we can return to it later.
	
			if (selection.count > 1) and (selSubObjectLevel != 0) then				-- So if there's more than one object selected and the subobjectmode is not '0'...
			(
				editMeshFlag = true			-- Then we set the edit mesh flag to true.
			)
			
			global selObjCPVs = kvs.buildObjCPVlist rollProgress selSubObjectLevel  mask_verts.checked			-- Now we need to pre-process the selected objects to make sure 
																												-- they have CPV topologies and to build the list of selected 
																												-- object CPVs which will be passed to the HSV modifier. The 
																												-- rollProgress variable is being passed so that the
																												-- kvs.buildObjCPVlist can modify the progress bar rollout. Scope 
																												-- issues would not permit this otherwise.
																												
			badObjCount = kvs.countCPVLessObjs selObjCPVs			-- Calls the kvs.countCPVLessObjs to count the number of objects that have no CPVs defined. A
																	-- non-zero count here will indicate that some objects do not have a vertex or face selected. Or
																	-- (when using vertex masking) objects whose vertex and face selections do not overlap. In any
																	-- case, we want to be able to catch those objects so that we don't crash the modifier by passing
																	-- it undefined data.																									
																												
			if (badObjCount > 0) then			-- So if badObjCount is not zero, then we have 1 or more objects without CPV selections. We
												-- therefore need to throw up an error message instead of running the modifier and letting it
												-- crash the script. The if statements that follow will be used to nail down exactly which
												-- error message we show the user.
			(
				if (selSubObjectLevel == 1) and (rollmodifiers.mask_verts.state == false)then
				(
					if (badObjCount == 1) then
					(
						messagebox ("1 selected object has no selected verts. You must select at least one vertex from each selected object.") \
							Title:"Vertex Selection Error"
					)
					else
					(
						messagebox (badObjCount as string + " selected objects have no selected verts. You must select at least one vertex from each selected object.") \
							Title:"Vertex Selection Error"
					)
				
				)
				else if (selSubObjectLevel == 1) and (rollmodifiers.mask_verts.state == true)then
				(
					messagebox ("The vertex and face selections for " + badObjCount as string + " object(s) do not overlap.") Title:"Vertex Masking Error"
				)
				else
				(
					if (badObjCount == 1) then
					(
						messagebox ("1 selected object has no selected faces. You must select at least one face from each selected object.") \
							Title:"Face Selection Error"
					)
					else
					(
						messagebox (badObjCount as string + " selected objects have no selected faces. You must select at least one face from each selected object.") \
							Title:"Face Selection Error"
					)		
				)
				
				-- Now that we've thrown up the error message and aborted running the modifier we need to close the
				-- progress bar, return the selected objects to the background plane, and return to whatever subobject 
				-- mode we started in.
				
				closeRolloutfloater progFloater			-- Closes the progress bar rollout.
				
				if (editMeshFlag == true) then			-- If the user invoked the modifier using a face or vertex selection made across
														-- multiple objects using an edit mesh modifier, then we want to return to the same
														-- state we were in before collapsing the stacks, etc. So if the edit mesh flag was
														-- set at the beginning of this event...
				(
					addmodifier selection (edit_mesh ())		-- We add an edit mesh modifier to the selection.
					
					subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
				)
				else 
				(
					subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
				)
								
				flagforeground selection false		-- Returns the selected objects to the background plane.
				
				rollModifiers.vs_timer.active = true			-- Turns the timer event back on.
			)
			else				-- If no objects had 0 CPV values stored, then we go ahead and run the 
								-- modifier. Since we're not in danger of crashing the script.
			(		
				for i in 1 to selObjCPVs.count do			-- Here we convert all of the bitarrays stored in selObjCPVs to ordinary arrays 
															-- Bitarrays are fast and memory efficient, but we want to be able to index
															-- the CPVs and the colors for those CPVs in the same way so there's no problems
															-- down the line. 
				(
					selObjCPVs[i] = selObjCPVs[i] as array
				)
				
				global selObjCPVColors = kvs.buildObjCPVColorlist selObjCPVs rollProgress		-- Now we need to take the array of CPV arrays we generated with the 
																								-- kvs.buildObjCPVlist function and build a corresponding array of 
																								-- colors for the CPVs we'll be working with. The kvs.buildObjCPVColorlist
																								-- will do this for us. Again, we have to pass the rollProgress variable
																								-- so that the function can modify the progress bar rollout.
				
				-- Now we need to determine the average value of the CPVs we're going to modify.
				
				valTotal = 0		-- Variable that will hold the total of all the selected CPV values added together.
				
				valCount = 0		-- Variable that will be used to count the number of CPV values we're adding together. 
				
				for i in 1 to selObjCPVColors.count do			-- Here we're iterating through each CPV color stored in selObjCPVColors
																-- and adding together all of their values. We'll then divide the total
																-- by the number of CPVs to find the average value we'll use for the 
																-- contrast calculations.
				(
					for j in 1 to selObjCPVcolors[i].count do
					(
						curColor = copy selObjCPVColors[i][j]
						
						-- Calculate which of the six major hue ranges we're in.
						hueRange = floor(curColor.hue / 42.5)
						if hueRange == 6 then hueRange = 0
						
						-- Calculate the saturation.
						colorSat = case hueRange of
						(
							0: curColor.r - curColor.b
							1: curColor.g - curColor.b
							2: curColor.g - curColor.r
							3: curColor.b - curColor.r
							4: curColor.b - curColor.g
							5: curColor.r - curColor.g
						)
					
						-- To find the value: First, convert the current color into it's purest hue.
						pureColor = copy curColor
						pureColor.saturation = 255
						pureColor.value      = 255
						
						-- Then, find the value of that pure color
						rVal = pureColor.r ^ 2.2
						gVal = pureColor.g ^ 2.2
						bVal = pureColor.b ^ 2.2
						
						pureHueVal = (0.227 * rVal) + (0.715 * gVal) + (0.058 * bVal)
						pureHueVal = (pureHueVal ^ 0.454545)
						pureHueVal /= 255.0
						
						-- Calculate the value (brightness) of our color.
						colorVal = case hueRange of
						(
							0: curColor.r - ((1.0 - pureHueVal) * colorSat)
							1: curColor.g - ((1.0 - pureHueVal) * colorSat)
							2: curColor.g - ((1.0 - pureHueVal) * colorSat)
							3: curColor.b - ((1.0 - pureHueVal) * colorSat)
							4: curColor.b - ((1.0 - pureHueVal) * colorSat)
							5: curColor.r - ((1.0 - pureHueVal) * colorSat)
						)
						
						-- We'll make sure the value we get is valid just in case it's not.
						if      colorVal > 255.0 then colorVal = 255.0
						else if colorVal < 0.0   then colorVal = 0.0
					
						valTotal += colorVal		-- Adds the current value to the value total.
						valCount += 1				-- Adds 1 to the number of CPVs processed.
					)
				)
				
				global valAverage = valTotal / valCount
				
				-- Now, there's a problem with the contrast calculation that gives very strange artifacts at the extreme low end of the contrast
				-- scale. These artifacts manifest themselves at slider values far below what would otherwise constitute zero contrast. So,
				-- rather than pull my hair out trying to tweak the value calculation, I've decided to simply truncate the value scale so that
				-- these problematic input values never occur in the first place.  Thus, the contrast slider will be given a value range of 0-100.
				-- And the following code will find the maximum required contrast range. The 0-100 value of the slider will then be used at the
				-- contrast function level to determine the final input value as a percentage of the contrast range found below.
				
				conHiRange = abs (255 - valAverage)			-- The range of value above the value average.
				
				conLoRange = 255 - conHiRange			    -- The range of value below the value average.
				
				if (conHiRange > conLoRange) then global conRange = conHiRange 			-- Here we pick the higher of the two value ranges and store it in conRange. This
											 else global conRange = conLoRange			-- value will then be passed to the contrast function and be used to determine the
											 											-- real value of the contrast slider.
				
				closeRolloutfloater progFloater		-- Closes the progress bar rollout.
				
				-- Contrast modifier is called here.
				
				global floatBC = newrolloutfloater "K's VertoShop" bcPanelWidth bcPanelHeight 700 630		-- Defines the floater for the Brightness/Contrast rollout.
				
				rollout rollBC "Brightness/Contrast"
				(
					-- Button and Slider Declarations.
					
					-- The Brightness slider and spinner.
					
					slider		sldBri 		"Brightness" 	pos:[15,16] 	width:375 	height:44 	range:[-256,255,0] 	type:#integer 	ticks:2
					spinner		spinBri		""				pos:[334,15]  	width:48 	height:18	range:[-256,255,0]	type:#integer
					
					-- The Contrast slider and spinner.
					
					slider 		sldCon 		"Contrast" 		pos:[15,73] 	width:375 	height:44 	range:[-100,100,0] 	type:#integer 	ticks:2
					spinner 	spinCon 	"" 				pos:[334,72]  	width:48 	height:18	range:[-100,100,0]	type:#integer
				
					-- The Ok, Reset, and Cancel buttons.
				
					button		btnOK		"OK"		pos:[413,14] 	width:75 	height:25
					button 		btnReset 	"Reset" 	pos:[413,42] 	width:75 	height:25
					button		btnCancel	"Cancel"	pos:[413,70] 	width:75 	height:25	
					
					-- The Realtime Update checkbox.
					
					checkbox	cbxRealtime		"Realtime Update" 		pos:[400,108]	checked:true		-- This checkbox will be used to toggle between the realtime
																											-- and update-on-mouseup viewport update modes.
					-- A timer that we'll use to make sure the user doesn't change the current selection.										
																	
					timer 	selTimer 	interval:250			-- A timer that we'll use to check whether each button should be enabled or not.
					
					-- The timer event.
					
					on selTimer tick do	
					(
						curSel = selection as array
					
						if initSelection as string != curSel as string then select initSelection
					)		
				
					-- The Brightness slider and spinner events.
					
					on sldBri changed foo do
					(
						spinBri.value = sldBri.value		-- Sets the Brightness spinner to the same value as the Brightness slider. 
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event.
						(
							kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange		-- Calls the kvs.hsvChange function to process 
																														-- the CPV colors of the selected objects.
		
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on sldBri buttonup do
					(
						kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange		-- Calls the kvs.hsvChange function to process 
																													-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
								
					on spinBri changed foo do
					(
						sldBri.value = spinBri.value		-- Sets the Brightness slider to the same value as the Brightness spinner.
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event.
						(
							kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange		-- Calls the kvs.hsvChange function to process 
																														-- the CPV colors of the selected objects.
		
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)			
					
					on spinBri buttonup do
					(
						kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange		-- Calls the kvs.hsvChange function to process 
																													-- the CPV colors of the selected objects.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)			
					
					-- The Contrast slider and spinner events.		
				
					on sldCon changed foo do
					(
						spinCon.value = sldCon.value		-- Sets the Contrast spinner to the same value as the Contrast slider. 
						
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event.
						(
							kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange		-- Calls the kvs.hsvChange function to process 
																														-- the CPV colors of the selected objects.
		
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on sldCon buttonup do
					(
						kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
								
					on spinCon changed foo do

					(
						sldCon.value = spinCon.value		-- Sets the Contrast spinner to the same value as the Contrast slider. 
					
						if cbxRealtime.checked then			-- If the Realtime Update checkbox is checked, then we'll process the objects'
															-- colors as the slider moves. If the Realtime Update checkbox isn't checked,
															-- then the objects will only be processed on the buttonup event.
						(
							kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange		-- Calls the kvs.hsvChange function to process 
																														-- the CPV colors of the selected objects.
		
							kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)			
					
					on spinCon buttonup do
					(
						kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)	
				
					-- The OK, Reset, and Cancel button events.
				
					on btnOK pressed do
					(
						closerolloutfloater floatBC			-- We close the BC floater. This will also trigger everything contained in the
															-- Close event defined below. This includes cleaning up the object CPVs.
					)
				
					on btnReset pressed do
					(
						-- First we reset all of the sliders and spinners to their default states.
					
						sldBri.value  = 0
						spinBri.value = 0
						
						sldCon.value  = 0
						spinCon.value = 0
					
						kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange		-- Then we call the kvs.bcChange function to reflect the change.
		
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on btnCancel pressed do
					(
						-- First we reset all of the sliders and spinners to their default states.
					
						sldBri.value  = 0
						spinBri.value = 0
						
						sldCon.value  = 0
						spinCon.value = 0
					
						kvs.bcChange selObjCPVs selObjCPVColors valAverage sldBri.value sldCon.value conRange		-- Then we call the kvs.bcChange function to reflect the change.
					
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					
						closerolloutfloater floatBC			-- We close the BC floater. This will also trigger everything contained in the
															-- Close event defined below. This includes cleaning up the object CPVs.
					)		
				
					on rollBC close do			-- This event will be called when the rollout is closed. Either by the user clicking the
												-- closebox on the floater window, or when the OK or Cancel event close the floater.
					(
						-- Now we clean up the CPV topologies for the objects just manipulated.
						
						rollProgress = kvs.cleanProgFloater()		-- Uses the cleanProgFloater function to pop up a floater with a progress
																	-- bar and variable text label on it so that the user can watch something 
																	-- while the cleanup routines are executing. Otherwise with large selections
																	-- the user might assume the script has crashed and kill Max.
						
						for i in 1 to selection.count do			-- Steps through all the selected objects.
						(
							rollProgress.workingon.text = ("Cleaning up: " + selection[i].name as string + "...")		-- Updates the workingon label in the progress rollout with
																														-- the name of the current object.
						
							if (classof selection[i] == editable_mesh) then			-- If the current object is an editable mesh...
							(
								kvs.cleancpvs selection[i]				-- We run the kvs.cleancpvs function on it to clean up it's CPV topography
																		-- so everything is nice and neat and efficient.
																	
								rollProgress.progress.value = (100 / selection.count) * i			-- Updates the cleanup progress bar.
							)
							else			-- If the current object is not an editable mesh...
							(
								rollProgress.progress.value = (100 / selection.count) * i			-- We just update the cleanup progress bar.
							)
						) 
						
						rollProgress.workingon.text = "Finishing up..."			-- Updates the workingon label text.
						
						closerolloutfloater progFloater			-- Closes the progress bar floater.
						
						if (editMeshFlag == true) then			-- If the user invoked the modifier using a face or vertex selection made across
																-- multiple objects using an edit mesh modifier, then we want to return to the same
																-- state we were in before collapsing the stacks, etc. So if the edit mesh flag was
																-- set at the beginning of this event...
						(
							addmodifier selection (edit_mesh ())		-- We add an edit mesh modifier to the selection.
							
							subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
						)
						else 
						(
							subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
						)
										
						flagforeground selection false		-- Returns the selected objects to the background plane.
						
						rollModifiers.vs_timer.active = true			-- Turns the timer event back on.
					)
				)
				addrollout rollBC floatBC		-- Adds the BC rollout to the BC floater.
			)
		)
		
		-------------------------------------------------------------------
		-- The XYZ Gradient Event.
		-------------------------------------------------------------------
		on btn_xyz_gradient pressed do
		(
			rollModifiers.vs_timer.active = false		-- Turns off the timer event so that it doesn't slow us down
														-- or cause other problems while it isn't needed.
														
			-- The following statements will disable the modifier buttons on the main KVS floater so that the
			-- user cannot call more than one modifier at a time. The rollout exit event will turn the timer
			-- back on which will automatically turn the appropriate modifier buttons back on as well.
		
			rollModifiers.mask_verts.enabled   		= false
			rollModifiers.btn_rgb_adjust.enabled   	= false
			rollModifiers.btn_hsv_adjust.enabled   	= false
			rollModifiers.btn_bc_adjust.enabled   	= false
			rollModifiers.btn_xyz_gradient.enabled 	= false
			rollModifiers.cpv_clean.enabled        	= false
		
			max modify mode		-- Makes sure the modify panel is active so that the subobject calls work.
			
			select (kvs.nonMeshSelCull())		-- Calls the kvs.nonMeshSelCull function to drop any non-mesh objects from the selection.
			
			flagforeground selection true		-- Increases redraw speed by bringing the selected objects to the foreground plane.

			
			global initSelection = selection as array		-- Stores the current selection as an array so that we can catch and prevent
															-- the user from changing the selection while the modifier panel is still open.
			
			global rollProgress = kvs.prepProgFloater()		-- Now, on small numbers of objects the following calculations will finish 
															-- quickly and HSV interface will pop up without much delay. But with large 
															-- numbers of objects the prep time may end up being quite long. So we'll 
															-- use the prepProgFloater function to create a floater with a progress bar 
															-- and variable text label. We can then update the floater as we prep the 
															-- objects so the user doesn't think the script has crashed. 
			
			global editMeshflag = false			-- If our user has selected faces and verts across multiple objects then we
												-- will need to throw an edit mesh across all the selected objects once the
												-- vertex color modifications are complete so that we can display their 
												-- selection as it was before the modifier was run. This is done because 
												-- scripted CPV modifications cannot be performed on meshes which have any
												-- modifiers applied to them.
	
			global selSubObjectLevel = subobjectlevel		-- Stores the pre-modifier sub-object level so that we can return to it later.
	
			if (selection.count > 1) and (selSubObjectLevel != 0) then				-- So if there's more than one object selected and the subobjectmode is not '0'...
			(
				editMeshFlag = true			-- Then we set the edit mesh flag to true.
			)
			
			global selObjCPVs = kvs.buildObjCPVlist rollProgress selSubObjectLevel  mask_verts.checked			-- Now we need to pre-process the selected objects to make sure 
																												-- they have CPV topologies and to build the list of selected 
																												-- object CPVs which will be passed to the HSV modifier. The 
																												-- rollProgress variable is being passed so that the
																												-- kvs.buildObjCPVlist can modify the progress bar rollout. Scope 
																												-- issues would not permit this otherwise.
																												
			badObjCount = kvs.countCPVLessObjs selObjCPVs			-- Calls the kvs.countCPVLessObjs to count the number of objects that have no CPVs defined. A
																	-- non-zero count here will indicate that some objects do not have a vertex or face selected. Or
																	-- (when using vertex masking) objects whose vertex and face selections do not overlap. In any
																	-- case, we want to be able to catch those objects so that we don't crash the modifier by passing
																	-- it undefined data.																									
																												
			if (badObjCount > 0) then			-- So if badObjCount is not zero, then we have 1 or more objects without CPV selections. We
												-- therefore need to throw up an error message instead of running the modifier and letting it
												-- crash the script. The if statements that follow will be used to nail down exactly which
												-- error message we show the user.
			(
				if (selSubObjectLevel == 1) and (rollmodifiers.mask_verts.state == false)then
				(
					if (badObjCount == 1) then
					(
						messagebox ("1 selected object has no selected verts. You must select at least one vertex from each selected object.") \
							Title:"Vertex Selection Error"
					)
					else
					(
						messagebox (badObjCount as string + " selected objects have no selected verts. You must select at least one vertex from each selected object.") \
							Title:"Vertex Selection Error"
					)
				
				)
				else if (selSubObjectLevel == 1) and (rollmodifiers.mask_verts.state == true)then
				(
					messagebox ("The vertex and face selections for " + badObjCount as string + " object(s) do not overlap.") Title:"Vertex Masking Error"
				)
				else
				(
					if (badObjCount == 1) then
					(
						messagebox ("1 selected object has no selected faces. You must select at least one face from each selected object.") \
							Title:"Face Selection Error"
					)
					else
					(
						messagebox (badObjCount as string + " selected objects have no selected faces. You must select at least one face from each selected object.") \
							Title:"Face Selection Error"
					)		
				)
				
				-- Now that we've thrown up the error message and aborted running the modifier we need to close the
				-- progress bar, return the selected objects to the background plane, and return to whatever subobject 
				-- mode we started in.
				
				closeRolloutfloater progFloater			-- Closes the progress bar rollout.
				
				if (editMeshFlag == true) then			-- If the user invoked the modifier using a face or vertex selection made across
														-- multiple objects using an edit mesh modifier, then we want to return to the same
														-- state we were in before collapsing the stacks, etc. So if the edit mesh flag was
														-- set at the beginning of this event...
				(
					addmodifier selection (edit_mesh ())		-- We add an edit mesh modifier to the selection.
					
					subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
				)
				else 
				(
					subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
				)
								
				flagforeground selection false		-- Returns the selected objects to the background plane.
				
				rollModifiers.vs_timer.active = true			-- Turns the timer event back on.
			)
			else				-- If no objects had 0 CPV values stored, then we go ahead and run the 
								-- modifier. Since we're not in danger of crashing the script.
			(
				for i in 1 to selObjCPVs.count do			-- Here we convert all of the bitarrays stored in selObjCPVs to ordinary arrays 
															-- Bitarrays are fast and memory efficient, but we want to be able to index
															-- the CPVs and the colors for those CPVs in the same way so there's no problems
															-- down the line. 
				(
					selObjCPVs[i] = selObjCPVs[i] as array
				)
						
				global selObjCPVColors = kvs.buildObjCPVColorlist selObjCPVs rollProgress		-- Now we need to take the array of CPV arrays we generated with the 
																								-- kvs.buildObjCPVlist function and build a corresponding array of 
																								-- colors for the CPVs we'll be working with. The kvs.buildObjCPVColorlist
																								-- will do this for us. Again, we have to pass the rollProgress variable
																								-- so that the function can modify the progress bar rollout.
																						
				global selObjCPVPositions = kvs.buildObjCPVPosList selobjCPVs 3			-- Calls the kvs.buildObjCPVPosList function to build the list of CPV positions
																						-- that we'll use to determine the specific color mix for each CPV.
				closeRolloutfloater progFloater		-- Closes the progress bar rollout.
				
				if (kvsXYZGradientOldColorA != undefined) and (kvsXYZGradientOldColorB != undefined) then		-- When the xyzGradient rollout is closed with the 'OK' button the
																												-- current A and B colors are saved to a set of persistent global
																												-- variables that will be saved to the scene file. The purpose is to
																												-- be able to use the same colors the next time the modifier is run.
																												-- Therefore, if these variables exist, we'll use the colors thus
																												-- stored as our defaults. Otherwise we'll just use white and black.
				(
					global defaultColorA = kvsXYZGradientOldColorA
					global defaultColorB = kvsXYZGradientOldColorB
				)								
				else
				(
					global defaultColorA = White
					global defaultColorB = Black
				)
												
				kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions defaultColorA defaultColorB 100 1 1 1			-- Runs the kvs.xyzGradient for the first time with the
																															-- default settings.
						
				kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
												
				-- Gradient Modifier is called here.
				
				global floatXYZ = newrolloutfloater "K's VertoShop" XYZGradPanelWidth xyzGradPanelHeight 700 630		-- Defines the floater for the Contrast rollout.
				
				rollout rollXYZ "XYZ Gradient"
				(
					label colorsLabel "Gradient Colors:"   					pos:[15,10]			-- Overall label for the gradient colors.
					
					colorPicker aColor 				   color:defaultColorA	pos:[18,30]			-- A colorpicker and label for the first gradient color.
					label 		aColorLabel "Color A"						pos:[68,38]
					
					colorPicker bColor  			   color:defaultColorB 	pos:[110,30]		-- A colorpicker and label for the second gradient color.
					label 		bColorLabel "Color B"						pos:[160,38]
					
					-- A slider and spinner for the gradient opacity adjustment.
					
					slider		sldOpac		"Gradient Opacity" 		pos:[15,67] 	width:375 	height:44 	range:[0,100,100] 	type:#integer 	ticks:4
					spinner		spinOpac	""						pos:[334,66]  	width:48 	height:18	range:[0,100,100]	type:#integer
					
					
					-- The radiobuttons for the Gradient Axis, Type, and Bounding options.
					
					radiobuttons gradAxis 	"Gradient Axis:" 	labels:#("X", "Y", "Z") 									pos:[15, 121]	  	columns:1  	default:3
					radiobuttons gradType 	"Gradient Type:" 	labels:#("Color A to Color B", "Color A to Transparent", "Transparent to Color B") 	pos:[105, 121] 	columns:1
					radiobuttons gradBounds "Gradient Bounds:" 	labels:#("Entire Selection","Per Object Selection") 		pos:[255, 121]  	columns:1
								
					-- the Swap Colors, OK, Reset, and Cancel Buttons.
					
					button		btnSwapColors	"Swap Colors"		pos:[213,28] 	width:95 	height:25
					button		btnOK			"OK"				pos:[413,28] 	width:75 	height:25
					button 		btnReset 		"Reset" 			pos:[413,56] 	width:75 	height:25
					button		btnCancel		"Cancel"			pos:[413,84] 	width:75 	height:25
				
					-- A couple of option checkboxes.
				
					checkbox	cbxRealtime		"Realtime Update" 		pos:[400,170]	checked:true		-- This checkbox will be used to toggle between the realtime
																											-- and update-on-mouseup viewport update modes.
		
					-- A timer that we'll use to make sure the user doesn't change the current selection.										
																	
					timer 	selTimer 	interval:250			-- A timer that we'll use to check whether each button should be enabled or not.
					
					-- The timer event.
					
					on selTimer tick do	
					(
						curSel = selection as array
					
						if initSelection as string != curSel as string then select initSelection
					)
								
					-- The ColorPicker Events.
					
					on aColor changed foo do
					(
						-- First we call the kvs.xyzGradient modifier to reflect the change.
						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on bColor changed foo do
					(
						-- First we call the kvs.xyzGradient modifier to reflect the change.
						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					-- The Opacity Slider Events.
					
					on sldOpac changed foo do
					(
						spinOpac.value = sldOpac.value		-- Assigns the slider value to the spinner so they'll both reflect the same value.
						
						if cbxRealtime.checked then
						(					
							-- Now we'll call the kvs.xyzGradient modifier to reflect the change.
							
							kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
							
							kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on sldOpac buttonup do
					(
						spinOpac.value = sldOpac.value		-- Assigns the slider value to the spinner so they'll both reflect the same value.
						
						-- Now we'll call the kvs.xyzGradient modifier to reflect the change.
						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on spinOpac changed foo do
					(
						sldOpac.value = spinOpac.value		-- Assigns the spinner value to the slider so they'll both reflect the same value.
						
						if cbxRealtime.checked then
						(				
							-- Now we'll call the kvs.xyzGradient modifier to reflect the change.
							
							kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
							
							kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
						)
					)
					
					on spinOpac buttonup do
					(
						sldOpac.value = spinOpac.value		-- Assigns the spinner value to the slider so they'll both reflect the same value.
						
						-- Now we'll call the kvs.xyzGradient modifier to reflect the change.
						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					-- The RadioButton Events.
					
					on gradAxis changed curAxis do
					(
						global selObjCPVPositions = kvs.buildObjCPVPosList selobjCPVs curAxis			-- Calls the kvs.buildObjCPVPosList function to build the list of CPV positions
																										-- that we'll use to determine the specific color mix for each CPV.
					
						-- Now we'll call the kvs.xyzGradient modifier to reflect the change.

						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on gradType changed foo do			-- The Gradient Type radiobutton event. The actual change is handled by the kvs.xyzGradient function.
														-- So all we do here is call the function as normal - passing along the new gradType state.
					(
						-- Now we'll call the kvs.xyzGradient modifier to reflect the change.
						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on gradBounds changed foo do		-- The Gradient Bounds radiobutton event. The actual change is handled by the kvs.xyzGradient function.
														-- So all we do here is call the function as normal - passing along the new gradBounds state.
					(
						-- Now we'll call the kvs.xyzGradient modifier to reflect the change.
						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
					)			
					
					-- The Reverse Colors button event.
					
					on btnSwapColors pressed do
					(
						tmpColorB = bColor.color
						
						bColor.color = aColor.color
						aColor.color = tmpColorB
		
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					-- The OK, Reset, and Cancel button events.			
																								
					on btnOK pressed do
					(
						-- First, we'll store the current colors for aColor and bColor in persistent global variables so
						-- we can use the same colors the next time the xyzGradient modifier is launched. And because they're
						-- 'persistent' global variables, they'll be saved along with the scene file itself.
					
						persistent global kvsXYZGradientOldColorA = aColor.color
						persistent global kvsXYZGradientOldColorB = bColor.color
					
						-- Now we'll call the kvs.xyzGradient modifier to reflect the change.
						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Then we call the kvs.updateAll function to update the viewport display for all the selected objects.
				
						closerolloutfloater floatXYZ		-- We close the XYZ Gradient floater. This will also trigger everything contained
															-- in the Close event defined below. This includes cleaning up the object CPVs.
					)
					
					on btnReset pressed do
					(
						-- First we reset all of the colorpickers, sliders, spinners, checkboxes, and radiobuttons to their default states.
					
						aColor.color = defaultColorA
						bColor.color = defaultColorB
					
						sldOpac.value  = 100
						spinOpac.value = 100
						
						gradAxis.state   = 3
						gradType.state 	 = 1
						gradBounds.state = 1
						
						-- Next we call the kvs.xyzGradient function to reflect the change.
						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					)
					
					on btnCancel pressed do
					(
						-- First we reset all of the colorpickers, sliders, spinners and radiobuttons to their default states.
					
						aColor.color = defaultColorA

						bColor.color = defaultColorB
					
						sldOpac.value  = 0		-- We're setting the opacity slider and spinner to zero instead of the default because
						spinOpac.value = 0		-- we want the original colors assigned to the object's CPVs and not the default gradient.
						
						gradAxis.state   = 3
						gradType.state 	 = 1
						gradBounds.state = 1
						
						-- Next we call the kvs.xyzGradient function to reflect the change.
						
						kvs.xyzGradient selObjCPVs selObjCPVColors selObjCPVPositions aColor.color bColor.color sldOpac.value gradAxis.state gradType.state gradBounds.state
						
						kvs.updateAll()		-- Calls the kvs.updateAll function to update the viewport display for all the selected objects.
					
						closerolloutfloater floatXYZ		-- We close the XYZ Gradient floater. This will also trigger everything contained
															-- in the Close event defined below. This includes cleaning up the object CPVs.
					)
					
					on rollXYZ close do			-- This event will be called when the rollout is closed. Either by the user clicking the
														-- closebox on the floater window, or when the OK or Cancel event close the floater.
					(
						-- Now we clean up the CPV topologies for the objects just manipulated.
						
						rollProgress = kvs.cleanProgFloater()		-- Uses the cleanProgFloater function to pop up a floater with a progress
																	-- bar and variable text label on it so that the user can watch something 
																	-- while the cleanup routines are executing. Otherwise with large selections
																	-- the user might assume the script has crashed and kill Max.
						
						for i in 1 to selection.count do			-- Steps through all the selected objects.
						(
							rollProgress.workingon.text = ("Cleaning up: " + selection[i].name as string + "...")		-- Updates the workingon label in the progress rollout with
																														-- the name of the current object.
						
							if (classof selection[i] == editable_mesh) then			-- If the current object is an editable mesh...

							(
								kvs.cleancpvs selection[i]				-- We run the kvs.cleancpvs function on it to clean up it's CPV topography
																		-- so everything is nice and neat and efficient.
																	
								rollProgress.progress.value = (100 / selection.count) * i			-- Updates the cleanup progress bar.
							)
							else			-- If the current object is not an editable mesh...
							(
								rollProgress.progress.value = (100 / selection.count) * i			-- We just update the cleanup progress bar.
							)
						) 
						
						rollProgress.workingon.text = "Finishing up..."			-- Updates the workingon label text.
						
						closerolloutfloater progFloater			-- Closes the progress bar floater.
						
						if (editMeshFlag == true) then			-- If the user invoked the modifier using a face or vertex selection made across
																-- multiple objects using an edit mesh modifier, then we want to return to the same
																-- state we were in before collapsing the stacks, etc. So if the edit mesh flag was
																-- set at the beginning of this event...
						(
							addmodifier selection (edit_mesh ())		-- We add an edit mesh modifier to the selection.
							
							subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
						)
						else 
						(
							subobjectlevel = selSubObjectLevel			-- And return to the same sub-object level we were at before.
						)
										
						flagforeground selection false		-- Returns the selected objects to the background plane.
						
						rollModifiers.vs_timer.active = true			-- Turns the timer event back on.
					)
				)		
				addrollout rollXYZ floatXYZ		-- Adds the BC rollout to the BC floater.
			)
		)	
		
		-------------------------------------------------------------------
		-- The CPV Rebuild Event
		-------------------------------------------------------------------
		
		on cpv_clean pressed do
		(
			rollModifiers.vs_timer.active = false		-- Turns off the timer event so that it doesn't slow us down
														-- or cause other problems while it isn't needed.
														
			-- The following statements will disable the modifier buttons on the main KVS floater so that the
			-- user cannot call more than one modifier at a time. The rollout exit event will turn the timer
			-- back on which will automatically turn the appropriate modifier buttons back on as well.
		
			rollModifiers.mask_verts.enabled   		= false
			rollModifiers.btn_rgb_adjust.enabled   	= false
			rollModifiers.btn_hsv_adjust.enabled   	= false
			rollModifiers.btn_bc_adjust.enabled   	= false
			rollModifiers.btn_xyz_gradient.enabled 	= false
			rollModifiers.cpv_clean.enabled        	= false
		

			max modify mode			-- Makes sure the modify panel is active so that the subobject calls work.
		
			-- Now, on small numbers of small objects the rebuild event will finish very quickly. But on
			-- large scenes of many objects it can a little while to complete. And if we don't show the
			-- user something he'll think the script has crashed or something. So we'll throw up a new 
			-- floater with a progress bar so they'll have some idea what's going on.
			
			progFloater = newrolloutfloater "Rebuild Object CPVs" 480 progFloatHeight 
		
			rollout rollProgress "Rebuilding Selected Mesh CPVs..."
			(
				progressbar progress color:red			-- A progress bar that will show our progress when
														-- processing the object faceIDs.
											
				label workingon "" align:#left			-- A label that we will update at each stage of
														-- the script to show where we are in the process.
			)
			
			addrollout rollProgress progFloater
		
			objsProcessed = 0		-- Variable to hold the number of objects processed.
			objsIgnored   = 0		-- Variable to hold the number of objects ignored because they aren't editable meshes.	
			
			for curobj in selection do			-- Loops through each selected object.
			(			
				rollProgress.workingon.text = ("Processing: " + curobj.name + "...")		-- Changes the workingon label in the rollprogress rollout
																							-- to the name of the current object being processed.
				
				if (classof curobj == editable_mesh) then		-- If the current object is an editable mesh...
				(
					collapsestack curobj		-- Collapses the current object's stack.
					
					curobj.showvertexcolors = true			-- Turn on it's vertex color display.
					
					if (getnumCPVverts curobj == 0) then		-- If the current mesh object doesn't have any CPVs already then
																-- we'll need to assign CPV verts and build the CPV face topology.
					(
						setnumcpvverts curobj curobj.verts.count		-- Sets the number of CPV verts as equal to the number of geometry verts.
						
						defaultvcfaces curobj		-- Builds the default CPV faces for the object.
						
						for curvert in curobj.verts do			-- Steps through each vertex in the object. Which in this virgin
																-- mesh will still match up perfectly with the geometry verts.
						(
							setvertcolor curobj curvert.index white			-- And we'll set each CPV's color to white.					
						)
						
						update curobj		-- Updates the viewport display for the current object.
						
						objsProcessed += 1		-- iterates the count of objects processed.
						
						rollProgress.progress.value = (100 / selection.count) * objsProcessed		-- Updates the progress bar.
					)
					else		-- And if the current mesh already has a CPV topology...
					(
						kvs.cleanCPVs curobj		-- We run the CPV cleaning function on it.
						
						objsProcessed += 1			-- iterates the count of objects processed.
						
						rollProgress.progress.value = (100 / selection.count) * objsProcessed		-- Updates the progress bar.
					)
				)
				else
				(
					objsIgnored   += 1		-- iterates the count of objects ignored.
					
					objsProcessed += 1		-- iterates the count of objects processed.
					
					rollProgress.progress.value = (100 / selection.count) * objsProcessed		-- Updates the progress bar.
				)
			)
	
			rollProgress.workingon.text = "Finishing up..."			-- Changes the workingon label in the rollprogress rollout so that if
																	-- the script hangs we know if the last object was rebuilt or not.
			
			messagebox "Rebuild(s) Complete." title:"Rebuild Object CPVs"		-- Lets the user know the rebuild is complete.
	
			if (objsIgnored != 0) then			-- If some objects were ignored by our script because they weren't editable meshes
												-- then we'll pop up another messagebox to say so.
			(
				messagebox (objsIgnored as string + " non-mesh objects were ignored.") title:"Rebuild Object CPVs"
			) 
	
			closeRolloutFloater progFloater			-- Closes the progress bar rollout.
	
			rollModifiers.vs_timer.active = true			-- Turns the timer event back on.		
		)
	)
	
	
	rollout rollHelpAbout "Help/About" rolledup:true
	(
		group "Help/About"
		(
			button vs_help  "Online Help" 			width:128 height:22	tooltip:vs_help_tip		-- Button for calling up the HTML help file from 
																								-- the goreham.net website.
		)
	
--		label 	  lblSupport_01 "This Tool Was Scripted By" pos:[10,25]
--		label 	  lblSupport_02 "     Keith M. Goreham"          pos:[10,40]
--		label 	  lblSupport_03 "Website:"					pos:[10,55]
--		hyperlink lnkWebsite 	"http://www.goreham.com" address:"http://www.goreham.com" color:Blue pos:[55, 40]	
		
		label copyright_label "©2005 by "	pos:[9, 60]	-- The first (non-clickable) half of the copyright notice. 
		
		hyperlink 	mailKeith 	"Keith M. Goreham" 	address:"http://www.goreham.com" color:Blue pos:[61, 60]		-- The 2nd hyperlinked part of the copyright notice. Clicking
																													-- on this link will send email to Keith Goreham, this script's
																													-- author.

		
		
		
		On vs_help pressed do
		(
			shelllaunch "http:\\\\www.goreham.com\\maxscripts\\kvs\\help\\index.htm" ""			-- Launches a browser window to the KVS help page on the goreham.net website.
		)
	)
	
	
	addrollout rollModifiers floater_vertoshop
	addRollout rollHelpAbout floater_vertoshop
)
