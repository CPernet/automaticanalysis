% AA initialisation module - evaluate wildcards in subject names
% Performs search using unix ls to convert wildcards into filenames
% Rhodri Cusack MRC CBU Cambridge 2004


function [aap,resp]=aamod_evaluatesubjectnames(aap,task,i)

resp='';

switch task
    case 'doit'
        issubj=false;
        isMRI = false; isMEG = false;
        if (length(aap.acq_details.subjects)>=i)
            if (~isempty(aap.acq_details.subjects(i).mriname))
                issubj = true;
                isMRI = true;
            end;
            if (strcmp(aap.acq_details.subjects(i).mriname,'missing'))
                aas_log(aap,0,sprintf('MRI from subject number %d is missing, hope you are doing MEG',i));
                issubj = false;
                isMRI = false;
            end;
            if (~isempty(aap.acq_details.subjects(i).megname))
                issubj = true;
                isMEG = true;
            end
        end;
        if (~issubj)
            aas_log(aap,1,sprintf('No subject name was specified for subject %d\n',i));
        end;
        switch (aap.directory_conventions.remotefilesystem)
            case 'none'
                if isMRI
                    s = mri_findvol(aap,aap.acq_details.subjects(i).mriname);
                    if isempty(s)
                        if isempty(aap.acq_details.subjects(i).megname)
                            aas_log(aap,0,sprintf('Problem finding subject %d raw data directory %s\n',i,aap.acq_details.subjects(i).mriname));
                        else
                            fprintf(' - Warning: Failed to find MRI for subject %d: %s\n',i,aap.acq_details.subjects(i).megname);
                            aap.acq_details.subjects(i).mriname='missing';
                        end
                    else
                        aap.acq_details.subjects(i).mriname=s;
                    end;
                end
                if isMEG
                    s = meg_findvol(aap,aap.acq_details.subjects(i).megname);
                    if isempty(s)
                        if isempty(aap.acq_details.subjects(i).megname)
                            aas_log(aap,0,sprintf('Problem finding subject %d raw data directory %s\n',i,aap.acq_details.subjects(i).mriname));
                        else
                            fprintf(' - Warning: Failed to find MEG for subject %d: %s\n',i,aap.acq_details.subjects(i).megname);
                            aap.acq_details.subjects(i).megname='missing';
                        end
                    else
                        aap.acq_details.subjects(i).megname=s;
                    end;
                end
            case 's3' % [TA] needs changing for enable multiple rawdatadir
                global aaworker
                % Separately match subject and visit parts
                mriname=aap.acq_details.subjects(i).mriname;
                while (mriname(end)=='/')
                    mriname=mriname(1:(end-1));
                end;
                [pth nme ext]=fileparts(mriname);
                subjectfilter=pth;
                visitfilter=[nme ext];
                
                % First subject, get list of all subjects
                [aap s3resp]=s3_list_objects(aap,aaworker.bucketfordicom,[aap.directory_conventions.rawdatadir '/'],[],'/');
                ind=cellfun(@(x) ~isempty(regexp(x,fullfile(aap.directory_conventions.rawdatadir,subjectfilter))),{s3resp.CommonPrefixes.Prefix});
                find_ind=find(ind);
                if (isempty(find_ind))
                    aas_log(aap,true,sprintf('Cannot find raw data for subject matching filter %s. These should now be regular expressions (e.g., CBU090800.*/.*)',subjectfilter));
                elseif (length(find_ind)>1)
                    aas_log(aap,true,sprintf('Found more than one raw data set matching subject filter %s. These should now be regular expressions (e.g., CBU090800.*/.*)',subjectfilter));
                end;
                matching_subject=s3resp.CommonPrefixes(find_ind).Prefix; % this will be the full path with trailing /... note this below
                
                % Now, visit filter, get list of all visits
                [aap s3resp]=s3_list_objects(aap,aaworker.bucketfordicom,matching_subject,[],'/');
                ind=cellfun(@(x) ~isempty(regexp(x,visitfilter)),{s3resp.CommonPrefixes.Prefix});
                find_ind=find(ind);
                if (isempty(find_ind))
                    aas_log(aap,true,sprintf('Cannot find raw data for visit matching filter %s. These should now be regular expressions (e.g., CBU090800.*/.*)',aap.acq_details.subjects(i).mriname));
                elseif (length(find_ind)>1)
                    aas_log(aap,true,sprintf('Found more than one raw data set matching visit filter %s. These should now be regular expressions (e.g., CBU090800.*/.*)',aap.acq_details.subjects(i).mriname));
                end;
                aap.acq_details.subjects(i).mriname=s3resp.CommonPrefixes(find_ind).Prefix((length(aap.directory_conventions.rawdatadir)+1):end);
                
                % Check registered in Drupal and put nid in acq_details
                [pth nme ext]=fileparts(aas_getsubjpath(aap,i));
                attr=[];
                attr.datasetalias.value=[nme ext];
                % Check bucket nid
                if (~isfield(aaworker,'bucket_drupalnid'))
                    [aap waserror aaworker.bucket_drupalnid]=drupal_checkexists(aap,'bucket',aaworker.bucket);
                end;
                % Check dataset nid for this subject
                [aap waserror aap.acq_details.subjects(i).drupalnid]=drupal_checkexists(aap,'dataset',aap.acq_details.subjects(i).mriname,attr,aaworker.bucket_drupalnid,aaworker.bucket);

        end;
                
    case 'checkrequirements'
        
end;
