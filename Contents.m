% MATLAB-VIDEO Video curation tools in Matlab
%
% Files
%   animateSingleReach        - Make 3D rendering of a specific reach in world coords
%   batchReachOnlyVidExport   - Export cropped/clipped trial vids for REACH ONLY task
%   batchTransferVids         - Copy a batch of videos to be transferred for extraction
%   batchVidExport            - Export cropped/clipped trial videos for a set of aligned vids
%   curateTrialMarkers        - Curate DLC labeling and fix/interpolate output
%   export3Dvids              - Export 3D-reconstructed videos for trial data
%   exportStereoCalImages     - Exports sets of images from each trial video
%   exportTrainingFrames      - Score video alignment of audio task in rat
%   fixScoringFileFormat      - Fix behaviorData table etc. for scoring file
%   getBlock                  - Get block path information
%   getStereoCalibration      - Recover camera pair stereo parameters
%   getSyncROI                - Get synchronization region-of-interest
%   getSyncThreshold          - Get threshold for LED in automated way
%   getTrials                 - Get trials from digital SYNC signal
%   getVidFile                - Returns metadata table for a related set of videos
%   getVidOffset              - Fixes video offset for each video
%   importDLC                 - Import numeric data from a text file as a matrix.
%   initCurationData          - Initialize curation data for a given recording
%   main                      - Batch for running code related to ROC for rats doing audio task
%   plot3DSegments            - Plot segments in 3D
%   reExportKinData           - Re-exports kinematic data after curation (for re-training)
%   scoreAudioTrials          - Score video alignment of audio task in rat
%   viewTrialKinematicMarkers - View kinematic markers for a given trial 
