FROM public.ecr.aws/lambda/python:3.9

ARG FUNCTION_DIR

COPY ${FUNCTION_DIR}/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ${FUNCTION_DIR}/app.py .

CMD ["app.lambda_handler"]