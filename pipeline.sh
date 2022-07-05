#!/bin/bash

## Change paths for the following variables

maindir=/mnt/Data/AnnaTmpFolder/
qsmscript=~/Scripts/QSMauto/bashqsm.sh
juliascript=${maindir}code/swi.jl
cbfscript=${maindir}code/CBF_quantification.py
cbftissue_script=${maindir}code/cbf_of_tissues.sh

cd $maindir


## Read input TSV file

if [ $# -lt 1 ];
  then
    echo "Syntax: pipeline [-f]"
    echo "options:"
    echo "-f File name of tsv (e.g. /mnt/Data/AnnaTmpFolder/TSV/pipeline_input.tsv)"
    echo
    exit 1;
fi

while getopts f: flag
do
    case "${flag}" in
        f) filename=${OPTARG};;
    esac
done


## Create output TSV file

mkdir -p ${maindir}TSV
output=/mnt/Data/AnnaTmpFolder/TSV/pipeline_output.tsv

echo -e "Subject_ID\tdHCP_Pipeline\tCSF_Volume\tGM_Volume\tWM_Volume\tBg_Volume\tVentricle_Volume\tCerebellum_Volume \
\tDeep_GM_Volume\tBrain_Stem_Volume\tHip_and_Amyg_Volume\tCSF_Chi\tGM_Chi\tWM_Chi\tBG_Chi \
\tVentricle_Chi\tCerebellum_Chi\tDeep_GM_Chi\tBrain_Stem_Chi\tHip_and_Amyg_Chi\tAvg_Chi_Vein\tCSF_CBF \
\tGM_CBF\tWM_CBF\tBG_CBF\tVentricle_CBF\tCerebellum_CBF\tDeep_GM_CBF\tBrain_Stem_CBF\tHip_and_Amyg_CBF" > ${output}
cat ${output}


## Loop pipeline through each row of the TSV file

{
    read
    while IFS=$'\t', read -r subjectid age t1w t2w asl dirap dirpa qsm hct csao2 threads
    do
        missing=false
        if [ "\t $subjectid" == "" ]
        then
            echo "Subject name (e.g. AMWCER12) is empty or no value set"
            missing=true
        elif [ "\t $age" == "" ]
        then
            echo "PMA at scan in weeks (e.g. 40) is empty or no value set"
            missing=true
        elif [ "\t $t1w" == "" ]
        then
            echo "T1 DICOM number (e.g. 1) is empty or no value set"
            missing=true
        elif [ "\t $t2w" == "" ]
        then
            echo "T2 DICOM number (e.g. 2) is empty or no value set"
            missing=true
        elif [ "\t $asl" == "" ]
        then
            echo "ASL DICOM number (e.g. 3) is empty or no value set"
            missing=true
        elif [ "\t $dirap" == "" ]
        then
            echo "DWI AP DICOM number (e.g. 4) is empty or no value set"
            missing=true
        elif [ "\t $dirpa" == "" ]
        then
            echo "DWI PA DICOM number (e.g. 5) is empty or no value set"
            missing=true
        elif [ "\t $qsm" == "" ]
        then
            echo "QSM DICOM number (e.g. 6) is empty or no value set"
            missing=true
        elif [ "\t $hct" == "" ]
        then
            echo "Hematocrit value (e.g. 0.318) is empty or no value set"
            missing=true
        elif [ "\t $csao2" == "" ]
        then
            echo "Cerebral arterial oxygen saturation value (e.g. 0.95) is empty or no value set"
            missing=true
        elif [ "\t $threads" == "" ]
        then
            echo "Thread number (e.g. 30) is empty or no value set"
            missing=true
        else
            echo "$subjectid read"
        fi

        if [ "$missing" = "true" ]
        then
            echo "ERROR: Missing values in $filename"
            exit 1
        else
            echo "$filename read successfully"
        fi

        sesid=session1
        subid=$subjectid

        echo $subid


        ## Create BIDS_config.json file

        innert1=$(jq -n --arg dt anat \
                        --arg md T1w \
                        --arg fn "$(printf "%03g" $t1w)*" \
                        '{dataType:$dt, modalityLabel:$md, criteria:{SidecarFilename:$fn}}'
        )
        innert2=$(jq -n --arg dt anat \
                        --arg md T2w \
                        --arg fn "$(printf "%03g" $t2w)*" \
                        '{dataType:$dt, modalityLabel:$md, criteria:{SidecarFilename:$fn}}'
        )
        innerasl=$(jq -n --arg dt perf \
                        --arg md asl \
                        --arg fn "$(printf "%03g" $asl)*" \
                        '{dataType:$dt, modalityLabel:$md, criteria:{SidecarFilename:$fn, ImageType:["DERIVED","PRIMARY","ASL","PERFUSION","ASL"]},
                        sidecarChanges:{ArterialSpinLabelingType:"PCASL",BackgroundSuppression:true,M0Type:"Separate",RepetitionTimePreparation:4.742}}'
        )
        innerasl2=$(jq -n --arg dt perf \
                        --arg md m0scan \
                        --arg fn "$(printf "%03g" $asl)*" \
                        '{dataType:$dt, modalityLabel:$md, criteria:{SidecarFilename:$fn, ImageType:["ORIGINAL","PRIMARY","ASL"]},
                        sidecarChanges:{RepetitionTimePreparation:4.742}}'
        )
        innerdirap=$(jq -n --arg dt dwi \
                        --arg md dwi \
                        --arg cl dir-AP \
                        --arg fn "$(printf "%03g" $dirap)*" \
                        '{dataType:$dt, modalityLabel:$md, customLabels:$cl, criteria:{SidecarFilename:$fn}}'
        )
        innerdirpa=$(jq -n --arg dt dwi \
                        --arg md dwi \
                        --arg cl dir-PA \
                        --arg fn "$(printf "%03g" $dirpa)*" \
                        '{dataType:$dt, modalityLabel:$md, customLabels:$cl, criteria:{SidecarFilename:$fn}, IntendedFor:[4], B0FieldIdentifier:"pepolar_fmap0"}'
        )
        jq -n --arg dcm2niixOptions "-b y -ba y -z y -f '%3s_%f_%d_%r'" \
            --argjson descriptions "[$innert1, $innert2, $innerasl, $innerasl2, $innerdirap, $innerdirpa]" \
            '$ARGS.named' > sourcedata/${subid}/BIDS_config.json

        #exit; 1


        ## Convert DICOM to NIfTI

        mkdir -p ${maindir}tmp_dcm2bids/sub-${subid}

        dcm2niix -o ${maindir}tmp_dcm2bids/sub-${subid} -b y -ba y -z y -f ‘%3s %f %d %r’ ${maindir}sourcedata/${subid}


        ## Run dcm2bids

        dcm2bids -d sourcedata/${subid}/ -p ${subid} -c sourcedata/${subid}/BIDS_config.json -o . --forceDcm2niix


        ## Run dHCP Anat

        mkdir ${maindir}derivatives

        docker run --rm -t -u $(id -u ${USER}):$(id -g ${USER}) -v $PWD:$PWD -w $PWD biomedia/dhcp-structural-pipeline:latest ${subid} ${sesid} ${age} \
            -T1 sub-${subid}/anat/sub-${subid}_T1w.nii.gz -T2 sub-${subid}/anat/sub-${subid}_T2w.nii.gz -t ${threads}
        
        ## Move dHCP files into derivatives/dhcp directory

        mkdir -p ${maindir}derivatives/dhcp
        mv ${maindir}derivatives/sub-${subid} ${maindir}derivatives/dhcp

        ## Get locations of masks and brains

        dhcpanat=${maindir}
        workingt1=${dhcpanat}workdir/${subid}-${sesid}/restore/T1/${subid}-${sesid}_restore
        derivt1=${dhcpanat}derivatives/dhcp/sub-${subid}/ses-${sesid}/anat/sub-${subid}_ses-${sesid}_T1w_restore
        [[ -f ${workingt1}.nii.gz ]] && t1=${workingt1}.nii.gz || t1=${derivt1}.nii.gz

        workingt2=${dhcpanat}workdir/${subid}-${sesid}/restore/T2/${subid}-${sesid}_restore
        derivt2=${dhcpanat}derivatives/dhcp/sub-${subid}/ses-${sesid}/anat/sub-${subid}_ses-${sesid}_T2w_restore
        [[ -f ${workingt2}.nii.gz ]] && t2=${workingt2}.nii.gz || t2=${derivt2}.nii.gz

        workingt2strip=${dhcpanat}workdir/${subid}-${sesid}/restore/T2/${subid}-${sesid}_restore_brain
        derivt2strip=${dhcpanat}derivatives/dhcp/sub-${subid}/ses-${sesid}/anat/sub-${subid}_ses-${sesid}_T2w_restore_brain
        [[ -f ${workingt2strip}.nii.gz ]] && t2strip=${workingt2strip}.nii.gz || t2strip=${derivt2strip}.nii.gz

        workingdseg=${dhcpanat}workdir/${subid}-${sesid}/segmentations/${subid}-${sesid}_tissue_labels
        derivdseg=${dhcpanat}derivatives/dhcp/sub-${subid}/ses-${sesid}/anat/sub-${subid}_ses-${sesid}_drawem_tissue_labels
        [[ -f ${workingdseg}.nii.gz ]] && dseg=${workingdseg}.nii.gz || dseg=${derivdseg}.nii.gz

        workingmask=${dhcpanat}workdir/${subid}-${sesid}/masks/${subid}-${sesid}
        derivmask=${dhcpanat}derivatives/dhcp/sub-${subid}/ses-${sesid}/anat/sub-${subid}_ses-${sesid}_brainmask_drawem
        [[ -f ${workingmask}.nii.gz ]] && mask=${workingmask}.nii.gz || mask=${derivmask}.nii.gz

        ## For subjects with dhcp files in workdir, move files from workdir to derivatives

        if [[ -f ${workingt1}.nii.gz && -f ${workingt2}.nii.gz && -f ${workingt2strip}.nii.gz && -f ${workingt2strip}.nii.gz && -f ${workingmask}.nii.gz ]]; then
            mkdir -p ${maindir}derivatives/dhcp/sub-${subid}/ses-${sesid}/anat/
            dhcpdir=${maindir}derivatives/dhcp/sub-${subid}/ses-${sesid}/anat/

            cp ${t1} ${dhcpdir}sub-${subid}_ses-${sesid}_T1w_restore.nii.gz
            cp ${t2} ${dhcpdir}sub-${subid}_ses-${sesid}_T2w_restore.nii.gz
            cp ${t2strip} ${dhcpdir}sub-${subid}_ses-${sesid}_T2w_restore_brain.nii.gz
            cp ${dseg} ${dhcpdir}sub-${subid}_ses-${sesid}_drawem_tissue_labels.nii.gz
            cp ${mask} ${dhcpdir}sub-${subid}_ses-${sesid}_brainmask_drawem.nii.gz

            echo "dhcp pipeline for this subject did not run successfully, files in this directory are copied from workdir" > ${dhcpdir}/readme.txt
            dhcp_status="Unsuccessful"
        else
            echo "dhcp pipeline successfully run, all files in derivatives directory"
            dhcp_status="Successful"
        fi


        ## Create individual tissue masks and directory

        mkdir -p ${maindir}derivatives/dhcp/sub-${subid}/ses-${sesid}/masks/
        maskdir=${maindir}derivatives/dhcp/sub-${subid}/ses-${sesid}/masks/

        fslmaths $dseg -thr 1 -uthr 1 -bin ${maskdir}csf
        fslmaths $dseg -thr 2 -uthr 2 -bin ${maskdir}cortgreymatter
        fslmaths $dseg -thr 3 -uthr 3 -bin ${maskdir}whitematter
        fslmaths $dseg -thr 4 -uthr 4 -bin ${maskdir}background
        fslmaths $dseg -thr 5 -uthr 5 -bin ${maskdir}vent
        fslmaths $dseg -thr 6 -uthr 6 -bin ${maskdir}cerebellum
        fslmaths $dseg -thr 7 -uthr 7 -bin ${maskdir}deepgrey
        fslmaths $dseg -thr 8 -uthr 8 -bin ${maskdir}brainstem
        fslmaths $dseg -thr 9 -uthr 9 -bin ${maskdir}hipandamyg


        ## Run code for QSM

        mkdir -p ${dhcpanat}derivatives/qsm/sub-${subid}
        ${qsmscript} ${dhcpanat}derivatives/qsm/sub-${subid} ${maindir}sourcedata/${subid}/Source/${qsm}/DICOM ${t2} ${maskdir}

        qsmdir=${dhcpanat}derivatives/qsm/sub-${subid}/
        cd ${qsmdir}

        ## Get last 3 echos of file

        fslroi chi.nii.gz chi_echo3-5 2 3 

        ## Get average over time of the last three echos

        fslmaths chi_echo3-5.nii.gz -Tmean chi_echo3-5_avg

        ## Threshold values below 0.15 and find mean of non-zero voxels (spits out X value for CSvO2)
        
        chivein=$(fslstats chi_echo3-5_avg.nii.gz -l 0.15 -M) 

        echo "Chi value for CSvO2: $chivein"


        ## Run code for SWI/R2*

        cd ${maindir}

        mkdir -p derivatives/swi/sub-${subid}/
        julia ${juliascript} ${subid} $PWD


        ## Run code for ASL

        mkdir -p derivatives/asl/sub-${subid}/

        ## Assign PW (asl) and PD (m0scan)

        pw=${maindir}sub-${subid}/perf/sub-${subid}_asl.nii.gz
        pd=${maindir}sub-${subid}/perf/sub-${subid}_m0scan.nii.gz

        ## Activate virtual envrionment (install nibabel as dependency on GPCC)
        
        source ~/env1/bin/activate

        asldir=${maindir}derivatives/asl/sub-${subid}/

        ${cbfscript} -pw $pw -pd $pd -o ${maindir}derivatives/asl/sub-${subid}/CBF_map.nii.gz

        cbf=$(${cbftissue_script} $asldir $pd $t2 $mask $dseg ${maindir}derivatives/asl/sub-${subid}/CBF_map.nii.gz $subid $sesid)

        ## Deactivate virtual envrionment
       
        deactivate


        ## Create variables and outputs for TSV file

        ## Find volume of tissue masks
        
        csfvol=$(fslstats ${maskdir}csf.nii.gz -V)
        gmvol=$(fslstats ${maskdir}cortgreymatter.nii.gz -V)
        wmvol=$(fslstats ${maskdir}whitematter.nii.gz -V)
        bgvol=$(fslstats ${maskdir}background.nii.gz -V)
        ventvol=$(fslstats ${maskdir}vent.nii.gz -V)
        cerebellumvol=$(fslstats ${maskdir}cerebellum.nii.gz -V)
        deepgmvol=$(fslstats ${maskdir}deepgrey.nii.gz -V)
        brainstemvol=$(fslstats ${maskdir}brainstem.nii.gz -V)
        hipandamygvol=$(fslstats ${maskdir}hipandamyg.nii.gz -V)

        ## Register tissues to QSM/chi
       
        chiavg=${qsmdir}chi_echo3-5_avg.nii.gz

        csfchi=$(fslstats ${chiavg} -k ${qsmdir}csf_wrapped_in_echo.nii.gz -M)
        gmchi=$(fslstats ${chiavg} -k ${qsmdir}cortgreymatter_wrapped_in_echo.nii.gz -M)
        wmchi=$(fslstats ${chiavg} -k ${qsmdir}whitematter_wrapped_in_echo.nii.gz -M)
        bgchi=$(fslstats ${chiavg} -k ${qsmdir}background_wrapped_in_echo.nii.gz -M)
        ventchi=$(fslstats ${chiavg} -k ${qsmdir}vent_wrapped_in_echo.nii.gz -M)
        cerebellumchi=$(fslstats ${chiavg} -k ${qsmdir}cerebellum_wrapped_in_echo.nii.gz -M)
        deepgmchi=$(fslstats ${chiavg} -k ${qsmdir}deepgrey_wrapped_in_echo.nii.gz -M)
        brainstemchi=$(fslstats ${chiavg} -k ${qsmdir}brainstem_wrapped_in_echo.nii.gz -M)
        hipandamygchi=$(fslstats ${chiavg} -k ${qsmdir}hipandamyg_wrapped_in_echo.nii.gz -M)

        ## Register tissues to ASL/CBF
       
        cbfmap=${maindir}derivatives/asl/sub-${subid}/CBF_map.nii.gz

        csfcbf=$(fslstats ${cbfmap} -k ${asldir}csf_in_pd.nii.gz -M)
        gmcbf=$(fslstats ${cbfmap} -k ${asldir}cortgreymatter_in_pd.nii.gz -M)
        wmcbf=$(fslstats ${cbfmap} -k ${asldir}whitematter_in_pd.nii.gz -M)
        bgcbf=$(fslstats ${cbfmap} -k ${asldir}background_in_pd.nii.gz -M)
        ventcbf=$(fslstats ${cbfmap} -k ${asldir}vent_in_pd.nii.gz -M)
        cerebellumcbf=$(fslstats ${cbfmap} -k ${asldir}cerebellum_in_pd.nii.gz -M)
        deepgmcbf=$(fslstats ${cbfmap} -k ${asldir}deepgrey_in_pd.nii.gz -M)
        brainstemcbf=$(fslstats ${cbfmap} -k ${asldir}brainstem_in_pd.nii.gz -M)
        hipandamygcbf=$(fslstats ${cbfmap} -k ${asldir}hipandamyg_in_pd.nii.gz -M)


        ## Output variables and values into TSV file

        echo -e "$subid\t$dhcp_status\t$csfvol\t$gmvol\t$wmvol\t$bgvol\t$ventvol\t$cerebellumvol\t$deepgmvol \
        \t$brainstemvol\t$hipandamygvol\t$csfchi\t$gmchi\t$wmchi\t$bgchi\t$ventchi\t$cerebellumchi \
        \t$deepgmchi\t$brainstemchi\t$hipandamygchi\t$chivein\t$csfcbf\t$gmcbf\t$wmcbf\t$bgcbf\t$ventcbf \
        \t$cerebellumcbf\t$deepgmcbf\t$brainstemcbf\t$hipandamygcbf" >> ${output}
        cat ${output}
    done
} < $filename
