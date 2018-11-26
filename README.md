# RADIATE

RADIATE is a ray-tracing software written in Fortran. Ray-traced delays can be calculated for observations in the microwave as well as in the optical frequency range. The computation is based on numerical weather models and the output files contain several tropospheric parameters


## Software requirements

RADIATE is a Fortran-written software to run from Linux command line (Terminal). To compile the software, the 'gfortran 5 compiler' (or newer version) needs to be installed.


## Dependencies

RADIATE is an independent software package of VieVS.


## Installation

For installation the following steps are required:
* Create a directory, for example 'VieVSsource'
* Clone the VieVS module RADIATE into the new directory using

```
$ cd your_directory/VieVSsource
$ git clone git@git.geo.tuwien.ac.at:vievs/RADIATE/RADIATE.git
```

The resulting folder structure should look the following:

```mermaid
graph LR;
VieVSsource --> RADIATE;
```


## Further information

You can find more detailed information on how to run RADIATE in the [VieVS Wiki] (http://vievswiki.geo.tuwien.ac.at/doku.php?id=internal:vievs_raytracer&s[]=radiate).