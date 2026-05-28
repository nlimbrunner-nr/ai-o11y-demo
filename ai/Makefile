build:
	pip install -r requirements.txt -t package/ \
		--platform manylinux2014_aarch64 \
		--implementation cp \
		--python-version 3.12 \
		--only-binary=:all:
	cp handler.py graphql_client.py system_prompt.txt package/
	cd package && zip -r ../function.zip .
	rm -rf package

clean:
	rm -f function.zip
	rm -rf package
