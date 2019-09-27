FROM python:3.6.5-slim
RUN echo Updating existing packages, installing and upgrading python and pip.
RUN pip3 install --upgrade pip
RUN echo Copying the Mythical Mysfits Flask service into a service directory.
COPY ./service /TrainETLService
WORKDIR /TrainETLService
RUN echo Installing Python packages listed in requirements.txt
RUN pip install -r ./requirements.txt
RUN echo Starting python and starting the Flask service...
ENTRYPOINT ["python"]
CMD ["etl_service.py"]
