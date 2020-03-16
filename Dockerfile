FROM nvidia/cuda:10.1-base-ubuntu16.04


# Install some basic utilities
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    sudo \
    git \
    bzip2 \
    libx11-6 \
    wget \
 && rm -rf /var/lib/apt/lists/*


# Install google-cloud-storage for saving model, etc.
#
#RUN pip install google-cloud-storage


# ---------------- SOURCE CODE --------------------
#

WORKDIR /workdir/sourcecode
# FIXME: Need to write these somewhere else.
#
RUN mkdir /workdir/data
RUN mkdir /workdir/models
RUN mkdir /workdir/samples


# Create a non-root user and switch to it
#RUN adduser --disabled-password --gecos '' --shell /bin/bash user \
# && chown -R user:user /workdir
#RUN echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-user
#USER user


# All users can use /home/user as their home directory
#ENV HOME=/home/user
#RUN chmod 777 /home/user


# Install Miniconda
# RUN mkdir /workdir/miniconda
# RUN curl -so /workdir/miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh \
RUN wget -nv https://repo.anaconda.com/miniconda/Miniconda3-4.5.12-Linux-x86_64.sh -O /workdir/miniconda.sh \
 && chmod +x /workdir/miniconda.sh \
 && /workdir/miniconda.sh -b -p /workdir/miniconda \
 && rm /workdir/miniconda.sh
ENV PATH=/workdir/miniconda/bin:$PATH
ENV CONDA_AUTO_UPDATE_CONDA=false

# Create a Python 3.6 environment
RUN /workdir/miniconda/bin/conda create -y --name py36 python=3.6.9 \
 && /workdir/miniconda/bin/conda clean -ya
ENV CONDA_DEFAULT_ENV=py36
ENV CONDA_PREFIX=/workdir/miniconda/envs/$CONDA_DEFAULT_ENV
ENV PATH=$CONDA_PREFIX/bin:$PATH
RUN /workdir/miniconda/bin/conda install conda-build=3.18.9=py36_3 \
 && /workdir/miniconda/bin/conda clean -ya


# CUDA 10.1-specific steps
RUN conda install -y -c pytorch \
   cudatoolkit=10.1 \
   "pytorch=1.4.0=py3.6_cuda10.1.243_cudnn7.6.3_0" \
   "torchvision=0.5.0=py36_cu101" \
&& conda clean -ya


# Install Requests, a Python library for making HTTP requests
# RUN conda install -y requests=2.19.1 \
#   && conda clean -ya


# Installs google cloud sdk, this is mostly for using gsutil to export model.
RUN wget -nv \
    https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz && \
    mkdir /workdir/tools && \
    tar xvzf google-cloud-sdk.tar.gz -C /workdir/tools && \
    rm google-cloud-sdk.tar.gz && \
    /workdir/tools/google-cloud-sdk/install.sh --usage-reporting=false \
        --path-update=false --bash-completion=false \
        --disable-installation-options && \
    rm -rf /workdir/.config/* && \
    ln -s /workdir/.config /config && \
    # Remove the backup directory that gcloud creates
    rm -rf /workdir/tools/google-cloud-sdk/.install/.backup


# Path configuration
ENV PATH $PATH:/workdir/tools/google-cloud-sdk/bin
# Make sure gsutil will use the default service account
RUN echo '[GoogleCompute]\nservice_account = default' > /etc/boto.cfg




# Copy the source tree into the docker image directory,
# as well as the dataset to train on.
### FIXME:
### - Seperate dataset from docker image. Perhaps store in Google cloud bucket.
###
COPY ./bmsg_gan/sourcecode /workdir/sourcecode
COPY ./butterfly /workdir/data



# Set the default command to python3
#CMD ["python3"]
#ENTRYPOINT ["python3", "./sourcecode/train.py"]
#ENTRYPOINT ["sh", "-c", "python -u train.py"]
ENTRYPOINT ["python", "-u", "train.py"]
