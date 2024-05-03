FROM python:3.12-slim

ARG FUNCTION_DIR
ARG SECRET

COPY ${FUNCTION_DIR}/abc.txt .
COPY ${FUNCTION_DIR2}/abc.txt ${secrets.GITHUB_TOKEN}
COPY app.py .

CMD ["python", "app.py", "${FUNCTION_DIR}", "${FUNCTION_DIR2}"]