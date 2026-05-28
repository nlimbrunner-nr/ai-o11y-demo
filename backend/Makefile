build:
	GOOS=linux GOARCH=arm64 go build -o bootstrap main.go

zip: build
	zip function.zip bootstrap data/users.json

clean:
	rm -f bootstrap function.zip
