! module_get_RayTrace2D_pwl_global.f90

!****************************************************************************
!
! PURPOSE:  Module containing subroutine to do piecewise-linear ray-tracing.
!    
!           Note: Created as module to avoid explicit inferface for the subroutine as needed because of assumed-shape arrays in subroutine.
!           
!           "get_RayTrace2D_pwl_global" is a subroutine to determine the path of the ray trough the atmosphere for
!           a specific initial elevation angle e0. The piece-wise linear propagation approach is used
!           (see scriptum Atmospheric Effects in Geodesy 2012). In this approach the azimuth of the ray is kept
!           constant. Therefore this ray-tracing method is a 2D approach.
!           
!           The outputs of this function are calculated total, hydrostatic and wet zenith and total,
!           hydrostatic and wet slant delays.
!           Furthermore the estimated elevation at the station, the ray-traced outgoing elevation angle as well
!           as its difference to the outgoing elevation from the azel-file (calculated, theoretical) angle
!           are reported.
!           All variables are stored in the structure "delay".
! 
!           --- Version Info ---
!           This version of the function is capable of using a global input grid, which contains the
!           refractive indices. Additionally input of values for refractive indices at station position
!           is necessary to do ray-tracing.
!           --------------------
!
!
! INPUT:
!         az............ azimuth of the observation in [rad]
!         e_outgoing.... outgoing (vacuum) elevation angle in [rad]
!         stat_lat...... latitude of station in [�]
!         stat_lon...... longitude of station in [�]
!         stat_height... (ellipsoidal) height of station in [m]
!         ind_lat1lon1_stat... index of point lat1lon1 in grid used for bilinear interpolation of values at station position
!         ind_lat1lon2_stat... index of point lat1lon2 in grid used for bilinear interpolation of values at station position
!         ind_lat2lon2_stat... index of point lat2lon2 in grid used for bilinear interpolation of values at station position
!         ind_lat2lon1_stat... index of point lat2lon1 in grid used for bilinear interpolation of values at station position
!         nr_h_lev...... total number of available height levels (from vertical interpolation/extrapolation)
!         h_lev_all..... (ellipsoidal) height levels in which the intersection points with the ray path should be estimated; in [m]
!                        attention: station height level is missing in this vector and station height lies somewhere in between
!                                   the input levels
!         start_lev..... index of first height level in "h_lev_all" above station height (needed for
!                        ray-tracing start above station)
!         grid_lat...... grid containing the latitude nodes around the station in [�]
!         grid_lon...... grid containing the longitude nodes around the station in [�]
!         grid_size..... size of the grid
!         dint_lat...... grid intervall for latitude in [�]
!         dint_lon...... grid intervall for longitude in [�]
!         n_m_stat...... mean value of the total refractive index between station height and first
!                        interpolated level above at the station's horizontal position
!         n_m_h_stat.... mean value of the hydrostatic refractive index between station height and first
!                        interpolated level above at the station's horizontal position
!         n_m_w_stat.... mean value of the wet refractive index between station height and first
!                        interpolated level above at the station's horizontal position
!         n_m........... gridded values of the total refractive index (mean between the two original
!                        height levels)
!         n_m_h......... gridded values of the hydrostatic refractive index (mean between the two original
!                        height levels)
!         n_m_w......... gridded values of the wet refractive index (mean between the two original
!                        height levels)
!         start_and_global_check... logical value telling if input grid has the desired starting
!                                   values in latitude and longitude and if it is a global grid in
!                                   latitude and longitude.
!                                   This information is needed when bilinear interpolation is done.
!                                   .TRUE. ... all checks are true, .FALSE. ... at least one check is false
! 
! 
! OUTPUT:
!         delay......... structure containing the following variables:
!           % dz_total........ zenith total delay in [m]
!           % dz_h............ zenith hydrostatic delay in [m]
!           % dz_w............ zenith wet delay in [m]
!           % ds_total_geom... slant total delay including geometric bending effect in [m]
!           % ds_total........ slant total delay in [m]
!           % ds_h_geom....... slant hydrostatic delay including geometric bending effect in [m]
!           % ds_h............ slant hydrostatic delay in [m]
!           % ds_w............ slant wet delay in [m]
!           % e_stat.......... elevation angle at the station in [rad]
!           % e_outgoing_rt... (iteratively) ray-traced outgoing elevation angle in [rad]
!           % diff_e.......... difference: outgoing (theoretical) - outgoing (ray-traced) elevation angle in [rad]
!           % dgeo............ geometric bending effect in [m]
!           % mf_total_geom... value for total mapping factor (includes treatment of geometric bending effect)
!           % mf_h_geom....... value for hydrostatic mapping factor (includes treatment of geometric bending effect)
!           % mf_w............ value for wet mapping factor
!           % break_elev...... logical signaling if a break in the while loop for calculating the
!                              outgoing elevation angle has occured (.FLASE.= no break, .TRUE.= break)
!           not specified in this subroutine:
!               % break_layer..... logical signaling if a break in the while loop for calculating the
!                                  next intersection point has occured (at least for one intersection point) (.FLASE.= no break, .TRUE.= break)
!
!----------------------------------------------------------------------------
! 
! Fortran-file created by Armin Hofmeister
!   based on Matlab scripts created by Armin Hofmeister
! 
!----------------------------------------------------------------------------
! History:
! 
! 12.02.2015: create the Fortran-file based on the Matlab subroutine "get_RayTrace2D_pwl_global.m"
! 16.02.2015: programming
! 17.02.2015: programming
! 18.02.2015: programming
! 19.02.2015: comments
! 25.02.2015: change variable in "determine_lat_lon" from raytrace % lat(1) to stat_lat and from raytrace % lon(1) to stat_lon
!             (no error, results remain unchanged)
! 26.02.2015: comments
! 02.03.2015: comments
! 07.05.2015: correct comments
! 13.05.2015: comments
! 02.06.2015: correct comments
! 09.06.2015: correct setting "break_elev" in case accuracy has been reached at last permitted
!             iteration loop
! 07.09.2015: enhance program code by avoiding unnecessary duplicate calculations of zenith refractive index
! 09.09.2015: correct comments
! 29.09.2015: replace the subroutine for the gaussian curvature radius by the euler radius of curvature
! 10.11.2015: move calculation of second ray point into loop and move persistent definitions at
!             station point out of the loop
! 19.11.2015: avoid unnecessary assignments of e_stat and e_outgoing_rt during iteration loop
!             correct comments
! 17.12.2015: add the total mapping factor calculation
!
!****************************************************************************

module module_get_RayTrace2D_pwl_global

contains

    subroutine get_RayTrace2D_pwl_global( az, &
                                          e_outgoing, &
                                          stat_lat, &
                                          stat_lon, &
                                          stat_height, &
                                          ind_lat1lon1_stat, &
                                          ind_lat1lon2_stat, &
                                          ind_lat2lon2_stat, &
                                          ind_lat2lon1_stat, &
                                          nr_h_lev_all, &
                                          h_lev_all, &
                                          start_lev, &
                                          grid_lat, &
                                          grid_lon, &
                                          grid_size, &
                                          dint_lat, &
                                          dint_lon, &
                                          n_m_stat, &
                                          n_m_h_stat, &
                                          n_m_w_stat, &
                                          n_m, &
                                          n_m_h, &
                                          n_m_w, &
                                          start_and_global_check, &
                                          delay )
        
        ! Define modules to be used
        use module_type_definitions, only: delay_type, raytrace_type
        
        use module_constants, only: deg2rad, rad2deg, accuracy_elev, limit_iterations_elev
        
        use module_R_earth_euler
        
        use module_get_bilint_value

        !----------------------------------------------------------------------------
    
        ! Variable definitions
        implicit none
    
    
        ! dummy arguments
        !----------------
    
        ! INPUT
    
        ! variable for storing azimuth of the observation in [rad]
        double precision, intent(in) :: az
        
        ! variable for storing outgoing (vacuum) elevation angle in [rad]
        double precision, intent(in) :: e_outgoing
        
        ! variable for storing latitude of station in [�]
        double precision, intent(in) :: stat_lat
    
        ! variable for storing longitude of station in [�]
        double precision, intent(in) :: stat_lon
    
        ! variable for storing (ellipsoidal) height of station in [m]
        double precision, intent(in) :: stat_height
        
        ! variable for storing index of point lat1lon1 in grid used for bilinear interpolation of values at station position
        integer, dimension(2), intent(in) :: ind_lat1lon1_stat
        
        ! variable for storing index of point lat1lon2 in grid used for bilinear interpolation of values at station position
        integer, dimension(2), intent(in) :: ind_lat1lon2_stat
        
        ! variable for storing index of point lat2lon2 in grid used for bilinear interpolation of values at station position
        integer, dimension(2), intent(in) :: ind_lat2lon2_stat
        
        ! variable for storing index of point lat2lon1 in grid used for bilinear interpolation of values at station position
        integer, dimension(2), intent(in) :: ind_lat2lon1_stat
        
        ! variable for storing total number of available height levels (from vertical interpolation/extrapolation)
        integer, intent(in) :: nr_h_lev_all
        
        ! variable for storing (ellipsoidal) height levels in which the intersection points with the ray path should be estimated; in [m]
        ! Attention: Station height level is missing in this vector and station height lies somewhere in between the input levels.
        double precision, dimension(nr_h_lev_all), intent(in) :: h_lev_all
        
        ! variable for storing index of first height level in "h_lev_all" above station height (needed for ray-tracing start above station)
        integer, intent(in) :: start_lev
        
        ! variable for storing grid containing the latitude nodes around the station in [�]
        double precision, dimension(:, :), intent(in) :: grid_lat
        
        ! variable for storing grid containing the longitude nodes around the station in [�]
        double precision, dimension(:, :), intent(in) :: grid_lon
        
        ! variable for storing size of the grid
        integer, dimension(:), intent(in) :: grid_size
        
        ! variable for storing grid interval in latitude in [�]
        double precision, intent(in) :: dint_lat
        
        ! variable for storing grid interval in longitude in [�]
        double precision, intent(in) :: dint_lon
        
        ! variable for storing mean value of the total refractive index between station height and
        ! first interpolated level above at the station's horizontal position
        double precision, intent(in) :: n_m_stat
                    
        ! variable for storing mean value of the hydrostatic refractive index between station height and
        ! first interpolated level above at the station's horizontal position
        double precision, intent(in) :: n_m_h_stat
                    
        ! variable for storing mean value of the wet refractive index between station height and
        ! first interpolated level above at the station's horizontal position
        double precision, intent(in) :: n_m_w_stat
                    
        ! variable for storing gridded values of the total refractive index
        ! (mean between the two original height levels)
        double precision, dimension(:, :, :), intent(in) :: n_m
                    
        ! variable for storing gridded values of the hydrostatic refractive index
        ! (mean between the two original height levels)
        double precision, dimension(:, :, :), intent(in) :: n_m_h
                    
        ! variable for storing gridded values of the wet refractive index
        ! (mean between the two original height levels)
        double precision, dimension(:, :, :), intent(in) :: n_m_w
                    
        ! variable for storing logical value telling if input grid has the desired starting
        ! values in latitude and longitude and if it is a global grid in latitude and longitude.
        ! Note: This information is needed when bilinear interpolation is done.
        !       .TRUE. ... all checks are true, .FALSE. ... at least one check is false
        logical, intent(in) :: start_and_global_check
        
        
        ! OUTPUT
        
        ! type for storing results from ray-tracing concerning the delays, the elevation angles, mapping factors and possible break in ray-tracing iteration
        type(delay_type), intent(out) :: delay
        
    
        ! local variables
        !----------------
        
        ! type for storing results from ray-tracing concerning the ray path
        type(raytrace_type) :: raytrace
        
        ! variable for storing the geocentric heights of height levels (h_lev with added radius of the Earth at station position)
        double precision, dimension(:), allocatable :: R
        
        ! variable for storing the linear distances (ray-part) between two intersection points in consecutive height levels
        double precision, dimension(:), allocatable :: s
        
        ! variable for storing the the geocentric y-coordinates of the ray points (= intersection points)
        double precision, dimension(:), allocatable :: y
        
        ! variable for storing the the geocentric z-coordinates of the ray points (= intersection points)
        double precision, dimension(:), allocatable :: z
        
        ! variable for storing the a priori bending effect
        double precision :: ap_bend
        
        ! variable for storing the first theta (location dependend elevation angle) = "theoretical" outgoing elevation angle + a priori bending effect
        double precision :: theta_start
        
        ! variable for storing the index of the ray-trace level starting with 1 at the station level
        integer :: ind_trace
        
        ! variable for counting the number of iteration loops when calculating the outgoing elevation angle
        integer :: loop_elev
        
        ! variable for index of (intermediate) height level used for getting the refractive indices during ray-tracing
        integer :: data_level
        
        ! loop variable
        integer :: i
        
        ! variable for storing height differences between two consecutive levels
        double precision, dimension(:), allocatable :: dh
        
        
        ! CONSTANTS
        
        ! see "module_constants" for "deg2rad", "rad2deg", "accuracy_elev", "limit_iterations_elev"
        
        !----------------------------------------------------------------------------
        
        !============================================================================
        ! Body of the subroutine
        !============================================================================
    
        
        ! Define transformation constants
        
        ! transformation constant from [�] to [rad]
        ! note: see "deg2rad" in "module_constants"
        ! transformation constant from [rad] to [�]
        ! note: see "rad2deg" in "module_constants"
        
        
        ! Define iteration conditions and message status
        
        ! define iteration accuracy of outgoing elevation angle in [rad]
        ! note: see "accuracy_elev" in "module_constants"
        
        ! define breaking limit via number of loops in the while loop for iteration of outgoing elevation angle
        ! note: see "limit_iterations_elev" in "module_constants"
        
        
        ! set status of message for breaking while loop when calculating outgoing elevation angle
        delay % break_elev= .FALSE.
        
        
        ! Calculate intersection points of the ray path with the height levels and determine values necessary for calculating the delays
        
        ! calculate radius of the Earth at station position using formula for the Euler radius of curvature
        ! attention: latitude and azimuth are required in [rad]
        call R_earth_euler( stat_lat * deg2rad, &
                            az, & ! note: already in [rad]
                            raytrace % R_e )
        
        ! get all height levels starting from station height up to last interpolated height level
        
        ! determine output of number of height levels starting at station level up to highest supported height level
        raytrace % nr_h_lev = nr_h_lev_all - start_lev + 2 ! note: +2 as station height level and "start_lev" are also needed
        
        ! allocate the output variable for storing the height levels from station level up to highest level
        allocate( raytrace % h_lev(raytrace % nr_h_lev) )
        
        ! station height level has to be added extra! Omit interpolation levels below station!
        raytrace % h_lev= [ stat_height, h_lev_all(start_lev:nr_h_lev_all) ] ! in [m]
        
        
        ! calulate geocentric heights of height levels
        
        ! allocate variable for storing the geocentric heights
        allocate( R(raytrace % nr_h_lev) )
        
        ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.60) on page 36
        ! Note: Adding the Earth radius calculated at the station's latitude to all height levels is sufficient,
        !       although it is an approximation as the radius changes as the ray path alters its latitude!
        !       Therefore a strict solution would need an iterative step to do ray-tracing, re-determine
        !       the radius and do ray-tracing and so on until a certain accuracy would be reached.
        R= raytrace % R_e + raytrace % h_lev ! in [m]
        
        
        ! allocate variables for the calculation of the intersection points
        ! note: some variables are also part of the output by the "raytrace" structure
        
        ! allocate all necessary output variables in "raytrace" using "raytrace % nr_h_lev" = number of levels from station level to highest height level
        ! note: setting the variables to NaN is not necessary as sizes are chosen correctly!
        allocate( raytrace % theta(raytrace % nr_h_lev), & ! define variable for elevation (location dependend)
                  raytrace % e(raytrace % nr_h_lev), & ! define variable for elevation (fixed reference to station position)
                  raytrace % anggeo(raytrace % nr_h_lev), & ! define variable for the geocentric angle
                  raytrace % ray_lat(raytrace % nr_h_lev), & ! define variable for latitude of ray points (intersection points with the height levels)
                  raytrace % ray_lon(raytrace % nr_h_lev), & ! define variable for longitude of ray points (intersection points with the height levels)
                  raytrace % ind_lat1lon1_trace(raytrace % nr_h_lev, 2), & ! define variables for the indices of the grid points used for interpolation, note: second dimensions allocated with size=2 as for storing the two indices of lat and lon
                  raytrace % ind_lat1lon2_trace(raytrace % nr_h_lev, 2), & ! define variables for the indices of the grid points used for interpolation, note: second dimensions allocated with size=2 as for storing the two indices of lat and lon
                  raytrace % ind_lat2lon2_trace(raytrace % nr_h_lev, 2), & ! define variables for the indices of the grid points used for interpolation, note: second dimensions allocated with size=2 as for storing the two indices of lat and lon
                  raytrace % ind_lat2lon1_trace(raytrace % nr_h_lev, 2), & ! define variables for the indices of the grid points used for interpolation, note: second dimensions allocated with size=2 as for storing the two indices of lat and lon
                  raytrace % n_total(raytrace % nr_h_lev), & ! define variable for the interpolated (at intersection point) mean total refractive indices
                  raytrace % n_h(raytrace % nr_h_lev), & ! define variable for the interpolated (at intersection point) mean hydrostatic refractive indices
                  raytrace % n_w(raytrace % nr_h_lev), & ! define variable for the interpolated (at intersection point) mean wet refractive indices
                  raytrace % n_total_z(raytrace % nr_h_lev), & ! define variable for the interpolated mean total refractive indices along the zenith direction
                  raytrace % n_h_z(raytrace % nr_h_lev), & ! define variable for the interpolated mean hydrostatic refractive indices along the zenith direction
                  raytrace % n_w_z(raytrace % nr_h_lev) ) ! define variable for the interpolated mean wet refractive indices along the zenith direction
        
        
        ! allocate remaining variables for the calculation of the intersection points that are not part of the "raytrace" output
        ! note: setting the variables to NaN is not necessary as sizes are chosen correctly!
        
        ! allocate variable for linear distances
        ! note: size= raytrace % nr_h_lev - 1 as the distances connect two levels and therefore their number is -1 of number of height levels
        allocate( s(raytrace % nr_h_lev - 1) )
        
        ! allocate variables for the geocentric coordinates of the ray points (= intersection points)
        allocate( y(raytrace % nr_h_lev), &
                  z(raytrace % nr_h_lev) )
        
        
        ! Piece-wise linear Approach
        ! see scriptum Atmospheric Effects in Geodesy 2012, equations (2.59 - 2.72) on pages 35 - 37
        
        ! calculate a priori bending effect
        ! see Hobiger et al. 2008, Fast and accurate ray-tracing algorithms for real-time space geodetic
        ! applications using numerical weather models, equation (32) on page 9
        ap_bend= 0.02d0 * exp(-stat_height / 6000) / tan(e_outgoing) * deg2rad ! in [rad], conversion is necessary!
        
        ! set initial theta (= location dependend) elevation angle
        ! first theta = "theoretical" outgoing elevation angle + a priori bending effect
        ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.61) on page 36
        theta_start= e_outgoing + ap_bend ! in [rad]
        
        ! set latitude of first intersection point (= station latitude)
        raytrace % ray_lat(1)= stat_lat ! in [�]
        
        ! set longitude of first intersection point (= station longitude)
        raytrace % ray_lon(1)= stat_lon ! in [�]
        
        
        ! get value of refractive index for the first height level (= mean of level at station height and interpolated layer above)
        
        ! set index for ray-trace level starting with 1 at the station level
        ind_trace= 1
        
        ! get slant total, hydrostatic and wet refractive indices value at the horizontal position of the first
        ! intersection point (= station position in intermediate level)
        raytrace % n_total(ind_trace)= n_m_stat
        raytrace % n_h(ind_trace)= n_m_h_stat
        raytrace % n_w(ind_trace)= n_m_w_stat
        
        ! assign indices of the grid points used for bilinear interpolation at station position and height
        raytrace % ind_lat1lon1_trace(ind_trace,:)= ind_lat1lon1_stat
        raytrace % ind_lat1lon2_trace(ind_trace,:)= ind_lat1lon2_stat
        raytrace % ind_lat2lon2_trace(ind_trace,:)= ind_lat2lon2_stat
        raytrace % ind_lat2lon1_trace(ind_trace,:)= ind_lat2lon1_stat
        
        
        ! define geocentric coordinates of the first ray point = first intersection point
        ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.63) on page 36
        z(1)= R(1) ! in [m]
        y(1)= 0 ! in [m]
        
        ! define the first geocentric angle
        ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.64) on page 36
        raytrace % anggeo(1)= 0 ! in [rad]
        
        
        ! define first value for "diff_e" (difference between "theoretical" outgoing elevation angle and
        ! ray-traced outgoing elevation angle) used for iteration decision
        ! note: make sure the initial value is higher than the value of "accuracy_elev"
        ! note: see "accuracy_elev" in "module_constants"
        delay % diff_e= 100 * accuracy_elev ! in [rad]
        
        ! initialize variable for counting the loop number for calculating the outgoing elevation angle
        loop_elev= 0
        
        ! loop in order to iterate outgoing elevation angle at the station
        ! note: see "accuracy_elev" in "module_constants"
        iteration_loop: do while ( abs(delay % diff_e) > accuracy_elev ) ! loop until absolute value is lower
            
            ! set first theta (= location dependend) elevation angle) to value retrieved for start (from
            ! initial setting or previous iteration loop)
            raytrace % theta(1)= theta_start
            
            ! set first elevation angle (fixed reference to station position)
            ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.61) on page 36
            raytrace % e(1)= raytrace % theta(1)
            
            
            ! loop to calculate all remaining ray points
            do i= 1, raytrace % nr_h_lev - 1 ! -1 as i+1 is needed inside the loop
                
                ! calculate linear distance to the next intersection point
                ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.67) on page 37
                s(i)= -R(i) * sin(raytrace % theta(i)) + sqrt( R(i+1)**2 - R(i)**2 * cos(raytrace % theta(i))**2 ) ! in [m]
                
                ! calculate geocentric coordinates of the next intersection point
                ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.68) on page 37
                z(i+1)= z(i) + s(i) * sin(raytrace % e(i)) ! in [m]
                y(i+1)= y(i) + s(i) * cos(raytrace % e(i)) ! in [m]
                
                ! define the geocentric angle to the next intersection point
                ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.69) on page 37
                raytrace % anggeo(i+1)= atan( y(i+1) / z(i+1) ) ! in [rad]
                
                
                ! calculate latitude and longitude of the next intersection point
                
                ! call subroutine to determine the latitude and longitude of the next intersection point from
                ! geocentric angles and azimuth (incl. check of values lying in the possible intervals)
                ! note: as we want to have a fixed azimuth to "az", it is necessary always to use the station's coordinates and geocentric angle as the first point
                call determine_lat_lon( raytrace % anggeo(1), & ! geocentric angle at station position
                                        raytrace % anggeo(i+1), &
                                        az, &
                                        stat_lat, &
                                        stat_lon, &
                                        raytrace % ray_lat(i+1), &
                                        raytrace % ray_lon(i+1) )
                
                
                ! determine refractive indices for the next intersection point (in intermediate level)
                
                ! define level of original data (first level is not the station height level!)
                ! attention: In order to get values of correct level: actually it is start_lev + (i+1) - 2 = start_lev + i - 1,
                !            where (i+1) is used to get to "next" level and -2 is needed to reduce the data level as station level
                !            and start_level introduce each an additional level number in the ray-tracing algorithm (see calculation of raytrace % nr_h_lev)
                ! note: in the last loop the data_level is equal to the last possible entry in the refractive index data base, i.e. setting an additional level with refractive
                !       indices =1 after the mean calculation is necessary! 
                data_level= start_lev + i - 1
                ! index for ray-trace level of current observation starting at the station
                ind_trace= i + 1
                
                ! slant
                ! get total, hydrostatic and wet slant refractive indices value at the next intersection point (in intermediate Level)
                ! note: see subroutine for optional arguments, use keywords for all arguments as specified in the subroutine to get correct call if some optional arguments are missing in between!
                call get_bilint_value( v1= n_m, &
                                       v2= n_m_h, &
                                       v3= n_m_w, &
                                       level= data_level, &
                                       POI_lat= raytrace % ray_lat(ind_trace), &
                                       POI_lon= raytrace % ray_lon(ind_trace), &
                                       dint_lat= dint_lat, &
                                       dint_lon= dint_lon, &
                                       grid_lat= grid_lat, &
                                       grid_lon= grid_lon, &
                                       grid_size= grid_size, &
                                       start_and_global_check= start_and_global_check, &
                                       v1_bilint= raytrace % n_total(ind_trace), &
                                       v2_bilint= raytrace % n_h(ind_trace), &
                                       v3_bilint= raytrace % n_w(ind_trace), &
                                       ind_lat1lon1_out= raytrace % ind_lat1lon1_trace(ind_trace,:), &
                                       ind_lat1lon2_out= raytrace % ind_lat1lon2_trace(ind_trace,:), &
                                       ind_lat2lon2_out= raytrace % ind_lat2lon2_trace(ind_trace,:), &
                                       ind_lat2lon1_out= raytrace % ind_lat2lon1_trace(ind_trace,:) )
                
                
                ! calculate elevation angle of ray path at the next intersection point (position specific elevation angle due to earth curvature)
                ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.71) on page 37
                raytrace % theta(i+1)= acos( raytrace % n_total(i) / raytrace % n_total(i+1) * cos( raytrace % theta(i) + raytrace % anggeo(i+1) - raytrace % anggeo(i) ) )
                
                ! calculate elevation angle (fixed reference at ray point)
                ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.72) on page 37
                raytrace % e(i+1)= raytrace % theta(i+1) - raytrace % anggeo(i+1)
                
            end do
            
            ! difference between "theoretical" outgoing elevation angle and ray-traced outgoing elevation angle
            ! note: the ray-traced outgoing elevation angle is the elevation angle value of the uppermost ray-traced level
            delay % diff_e= e_outgoing - raytrace % e(raytrace % nr_h_lev) ! in [rad]
            
            ! raise counter for loop_elev
            loop_elev= loop_elev + 1
            
            ! break while loop if number of iterations has reached defined limit
            ! note: see "limit_iterations_elev" in "module_constants"
            if (loop_elev >= limit_iterations_elev) then
                ! check if accuracy is still not reached with last iteration
                ! note: break of loop is done afterwards anyway, but setting of "break_elev" to .TRUE. may be skipped
                if ( abs(delay % diff_e) > accuracy_elev ) then
                    ! set message variable to .TRUE. to indicate that break has occurred
                    delay % break_elev= .TRUE.
                end if
                
                ! exit the do while loop ("iteration_loop")
                exit iteration_loop
            end if
            
            ! determine new starting elevation angle at the station based on the difference between
            ! "theoretical" and ray-traced outgoing elevation angle
            theta_start= theta_start + delay % diff_e ! in [rad]
            
        end do iteration_loop
        
        ! get starting elevation angle at station
        delay % e_stat= raytrace % theta(1) ! in [rad]
        
        ! define outgoing elevation angle (location independent)
        ! note: this is the elevation angle value of the uppermost ray-traced level
        delay % e_outgoing_rt= raytrace % e(raytrace % nr_h_lev) ! in [rad]
            
        
        ! Determine the zenith refractive indices
        ! note: This step is done outside the ray-tracing loop since no iteration is needed in the zenith direction.
        
        ! set index for ray-trace level starting with 1 at the station level
        ind_trace= 1
        
        ! get value of refractive index for the first height level (= mean of level at station height and interpolated layer above)
        ! zenith refractive indices at first level are equal to slant refractive indices at first intermediate level
        ! (station level) and therefore equal to values calculated for the station level
        raytrace % n_total_z(ind_trace)= n_m_stat
        raytrace % n_h_z(ind_trace)= n_m_h_stat
        raytrace % n_w_z(ind_trace)= n_m_w_stat
        
        ! loop over all remaining height levels
        loop_zenith: do i= 1, raytrace % nr_h_lev - 1 ! -1 as i+1 is needed inside the loop
            
            ! define level of original data (first level is not the station height level!)
            ! attention: In order to get values of correct level: actually it is start_lev + (i+1) - 2 = start_lev + i - 1,
            !            where (i+1) is used to get to "next" level and -2 is needed to reduce the data level as station level
            !            and start_level introduce each an additional level number in the ray-tracing algorithm (see calculation of raytrace % nr_h_lev)
            ! note: in the last loop the data_level is equal to the last possible entry in the refractive index data base, i.e. setting an additional level with refractive
            !       indices =1 after the mean calculation is necessary! 
            data_level= start_lev + i - 1
            ! index for ray-trace level of current observation starting at the station
            ind_trace= i + 1
            
            ! zenith
            ! get total, hydrostatic and wet zenith refractive indices value at the horizontal position of
            ! the station in the height level of the next intersection point (in intermediate level)
            ! note: see subroutine for optional arguments, use keywords for all arguments as specified in the subroutine to get correct call if some optional arguments are missing in between!
            call get_bilint_value( v1= n_m, &
                                   v2= n_m_h, &
                                   v3= n_m_w, &
                                   level= data_level, &
                                   POI_lat= stat_lat, &
                                   POI_lon= stat_lon, &
                                   dint_lat= dint_lat, &
                                   dint_lon= dint_lon, &
                                   ind_lat1lon1_in= ind_lat1lon1_stat, & ! input of indices to avoid the call of subroutine to determine them as indices have already been determined in the subroutine "calc_refr_ind_at_stations"
                                   ind_lat1lon2_in= ind_lat1lon2_stat, & ! grid_lat, grid_lon, grid_size and start_and_global_check are therefore not needed
                                   ind_lat2lon2_in= ind_lat2lon2_stat, &
                                   ind_lat2lon1_in= ind_lat2lon1_stat, &
                                   v1_bilint= raytrace % n_total_z(ind_trace), &
                                   v2_bilint= raytrace % n_h_z(ind_trace), &
                                   v3_bilint= raytrace % n_w_z(ind_trace) )
        end do loop_zenith
        
        
        ! Calculate zenith and slant delays (total, hydrostatic and wet)
        
        ! determine height differences between two consecutive levels
        ! allocate variable for storage
        allocate( dh(raytrace % nr_h_lev - 1) ) ! note: number must be number ot levels - 1
        ! note: as earth radius "R_e" is constant, it is sufficient to directly use the "h_lev" values
        dh= (raytrace % h_lev(2:raytrace % nr_h_lev) - raytrace % h_lev(1:raytrace % nr_h_lev - 1))
        
        
        ! calculate zenith delays
        ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.74) on page 38 + conversion from
        ! refractivity to refractive index
        
        ! calculate zenith total delay
        ! note: dot_product() does the following: sum(vector_a * vector_b), where vector_a * vector_b is the element-wise multiplication
        delay % dz_total= dot_product( (raytrace % n_total_z(1:raytrace % nr_h_lev - 1) - 1),  dh ) ! in [m]; attention because of estimating raytrace % n_total_z in the loop from i=2:nr_lev-1 and calculating always raytrace % n_total_z(i+1) the last value for raytrace % n_total_z is not needed
        ! calculate zenith hydrostatic delay
        delay % dz_h= dot_product( (raytrace % n_h_z(1:raytrace % nr_h_lev - 1) -1 ), dh ) ! in [m]; attention because of estimating raytrace % n_h_z in the loop from i=2:nr_lev-1 and calculating always raytrace % n_h_z(i+1) the last value for raytrace % n_h_z is not needed
        ! calculate zenith wet delay
        delay % dz_w= dot_product( (raytrace % n_w_z(1:raytrace % nr_h_lev - 1) - 1), dh ) ! in [m]; attention because of estimating raytrace % n_w_z in the loop from i=2:nr_lev-1 and calculating always raytrace % n_w_z(i+1) the last value for raytrace % n_w_z is not needed
        
        
        ! calculate slant delays
        ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.73) on page 38 + conversion from
        ! refractivity to refractive index
        
        ! calculate slant total delay
        delay % ds_total= dot_product( (raytrace % n_total(1:raytrace % nr_h_lev - 1) - 1), s ) ! in [m]; attention because of estimating raytrace % n_total in the loop from i=2:nr_lev-1 and calculating always raytrace % n_total(i+1) the last value for raytrace % n_total is not needed
        !% calculate slant hydrostatic delay
        delay % ds_h= dot_product( (raytrace % n_h(1:raytrace % nr_h_lev-1) - 1), s ) ! in [m]; attention because of estimating raytrace % n_h in the loop from i=2:nr_lev-1 and calculating always raytrace % n_h(i+1) the last value for raytrace % n_h is not needed
        !% calculate slant wet delay
        delay % ds_w= dot_product( (raytrace % n_w(1:raytrace % nr_h_lev-1) - 1), s ) ! in [m]; attention because of estimating raytrace % n_w in the loop from i=2:nr_lev-1 and calculating always raytrace % n_w(i+1) the last value for raytrace % n_w is not needed
        
        
        ! Calculate geometric bending effect
        
        ! see scriptum Atmospheric Effects in Geodesy 2012, equation (2.75) on page 38
        ! note: as there are only vectors and a scalar, it is not necessary to specify a dimension for the sum() function
        delay % dgeo= sum( s - cos(raytrace % e(1:raytrace % nr_h_lev-1) - delay % e_outgoing_rt) * s ) ! in [m]
        
        
        ! Calculate delays including geometric bending effect
        
        ! slant hydrostatic delay + geometric bending effect
        delay % ds_h_geom = delay % ds_h + delay % dgeo ! in [m]
        
        ! calculate slant total delay + geometric bending effect
        delay % ds_total_geom = delay % ds_total + delay % dgeo ! in [m]
        
        
        ! Calculate mapping factor values
        
        ! calculate value for total mapping factor (includes treatment of geometric bending effect)
        delay % mf_total_geom = delay % ds_total_geom / delay % dz_total
        
        ! calculate value for hydrostatic mapping factor (includes treatment of geometric bending effect)
        ! see B�hm and Schuh (2003) "Vienna Mapping Functions" in Working Meeting on European VLBI for Geodesy and Astrometry
        ! equation (A26)
        delay % mf_h_geom = delay % ds_h_geom / delay % dz_h
        
        ! calculate value for wet mapping factor
        ! see B�hm and Schuh (2003) "Vienna Mapping Functions" in Working Meeting on European VLBI for Geodesy and Astrometry
        ! equation (A27)
        delay % mf_w = delay % ds_w / delay % dz_w
        
        
        ! Assign output variables to output structure variable "raytrace" and transform the values
        ! note: this is done only for variables that are still missing or for variables that need to be transformed e.g. from [rad] to [deg]
        raytrace % az= az * rad2deg ! in [�], "rad2deg" specified in "module_constants"
        raytrace % theta= raytrace % theta * rad2deg ! in [�]
        raytrace % e= raytrace % e * rad2deg ! in [�]
        raytrace % anggeo= raytrace % anggeo * rad2deg ! in [�]
        
    end subroutine get_RayTrace2D_pwl_global
    
end module module_get_RayTrace2D_pwl_global