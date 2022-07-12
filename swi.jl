using CLEARSWI

TEs = [5,10.24,15.48,20.72,25.96] # change this to the Echo Time of your sequence. For multi-echoes, set a list of TE values, else set a list with a single TE value.
subject = string("sub-", ARGS[1])
qsmfolder = joinpath(ARGS[2], "derivatives/qsm", subject)
outfolder = joinpath(ARGS[2], "derivatives/swi", subject)
magfile = joinpath(qsmfolder, "mag.nii.gz") # Path to the magnitude image in nifti format, must be .nii or .hdr
phasefile = joinpath(qsmfolder, "phas.nii.gz") # Path to the phase image
maskfile = joinpath(qsmfolder, "mag_echo5_sqr_brain_mask.nii.gz")


mag = readmag(magfile);
phase = readphase(phasefile);
mask = readmag(maskfile);
mask = iszero.(mask);
data = Data(mag, phase, mag.header, TEs);

swi = calculateSWI(data);
mip = createIntensityProjection(swi, maximum); # maximum intensity projection, other Julia functions can be used instead of minimum
#mip = createMIP(swi); # shorthand for createIntensityProjection(swi, minimum)

savenii(swi, joinpath(outfolder, "swi.nii.gz"));
savenii(mip, joinpath(outfolder, "mip.nii.gz"));

using MriResearchTools

unwrapped = romeo(phase; mag=mag, TEs=TEs, mask=mask); # type ?romeo in REPL for options
B0 = calculateB0_unwrapped(unwrapped, mag, TEs); # inverse variance weighted

t2s = NumART2star(mag, TEs);
r2s = r2s_from_t2s(t2s);

savenii(t2s, joinpath(outfolder, "t2s.nii.gz"));
savenii(r2s, joinpath(outfolder, "r2s.nii.gz"));
savenii(B0, joinpath(outfolder, "B0.nii.gz"));
savenii(unwrapped, joinpath(outfolder, "unwrapped.nii.gz"));
