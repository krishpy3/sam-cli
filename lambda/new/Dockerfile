# Define the base image. AWS provides base images for Python which we can use.
FROM public.ecr.aws/lambda/python:3.9

COPY requirements.txt  .
# Install any function dependencies
RUN  pip install --no-cache-dir -r requirements.txt

# Copy the handler function
COPY app.py ./ 
# Set the CMD to your handler (could also be done via function's configuration in AWS Console)
CMD ["app.lambda_handler"]
