### 3.4 Define Run Variables

export PATH_NUM=448
export FRAME_NUM=0290

export PADDED_PATH=p${PATH_NUM}
export PADDED_FRAME=f${FRAME_NUM}
export FRAME_TAG=P${PATH_NUM}F${FRAME_NUM}

export BASE_DIR=/eggraid/home/$USER/projects/linog/insar
export WORK_DIR=${BASE_DIR}/${PADDED_PATH}/${PADDED_FRAME}

## 4. Directory Organization and Naming Conventions

${PADDED_PATH}/${PADDED_FRAME}/
  raw/
  data -> raw
  unzipped/
  SLC/
  DEM/
  run_files/
  interferograms/
  logs/
  Igrams/
  mintpy/
    geo/
      LInOG_Upload_${FRAME_TAG}/