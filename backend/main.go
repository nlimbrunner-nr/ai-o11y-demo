package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/graphql-go/graphql"

	"github.com/ai-o11y/backend/graph"
)

var schema graphql.Schema

func init() {
	resolver := &graph.Resolver{}
	var err error
	schema, err = graph.NewSchema(resolver)
	if err != nil {
		log.Fatalf("failed to build GraphQL schema: %v", err)
	}
}

type graphqlRequest struct {
	Query         string                 `json:"query"`
	OperationName string                 `json:"operationName"`
	Variables     map[string]interface{} `json:"variables"`
}

type graphqlResponse struct {
	Data   interface{}              `json:"data"`
	Errors []map[string]interface{} `json:"errors,omitempty"`
}

func handler(ctx context.Context, req events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	corsHeaders := map[string]string{
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Headers": "Content-Type,Authorization",
		"Access-Control-Allow-Methods": "POST,OPTIONS",
		"Content-Type":                 "application/json",
	}

	// Handle preflight CORS requests.
	if req.RequestContext.HTTP.Method == "OPTIONS" {
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 204,
			Headers:    corsHeaders,
		}, nil
	}

	var gqlReq graphqlRequest
	if err := json.Unmarshal([]byte(req.Body), &gqlReq); err != nil {
		body, _ := json.Marshal(map[string]string{"error": "invalid JSON body"})
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 400,
			Headers:    corsHeaders,
			Body:       string(body),
		}, nil
	}

	result := graphql.Do(graphql.Params{
		Schema:         schema,
		RequestString:  gqlReq.Query,
		OperationName:  gqlReq.OperationName,
		VariableValues: gqlReq.Variables,
		Context:        ctx,
	})

	resp := graphqlResponse{
		Data: result.Data,
	}
	if len(result.Errors) > 0 {
		errs := make([]map[string]interface{}, 0, len(result.Errors))
		for _, e := range result.Errors {
			errs = append(errs, map[string]interface{}{"message": e.Message})
		}
		resp.Errors = errs
	}

	body, err := json.Marshal(resp)
	if err != nil {
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Headers:    corsHeaders,
			Body:       `{"error":"internal server error"}`,
		}, nil
	}

	return events.APIGatewayV2HTTPResponse{
		StatusCode: 200,
		Headers:    corsHeaders,
		Body:       string(body),
	}, nil
}

func main() {
	lambda.Start(handler)
}
