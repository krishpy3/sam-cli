FROM python:3.12-slim

ARG FUNCTION_DIR
ARG FUNCTION_DIR2

COPY ${FUNCTION_DIR}/abc.txt .
COPY ${FUNCTION_DIR2}/abc.txt c.txt
COPY app.py .

CMD ["python", "app.py", "${FUNCTION_DIR}", "${FUNCTION_DIR2}"]