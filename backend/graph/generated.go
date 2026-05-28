package graph

import (
	"context"
	"fmt"
	"reflect"

	"github.com/graphql-go/graphql"
)

// resolveField extracts a named struct field from source using reflection.
// source is expected to be a pointer to a struct.
func resolveField(source interface{}, fieldName string) interface{} {
	if source == nil {
		return nil
	}
	v := reflect.ValueOf(source)
	if v.Kind() == reflect.Ptr {
		if v.IsNil() {
			return nil
		}
		v = v.Elem()
	}
	if v.Kind() != reflect.Struct {
		return nil
	}
	f := v.FieldByName(fieldName)
	if !f.IsValid() {
		return nil
	}
	return f.Interface()
}

// vehicleType is the GraphQL object type for Vehicle.
var vehicleType = graphql.NewObject(graphql.ObjectConfig{
	Name: "Vehicle",
	Fields: graphql.Fields{
		"id": &graphql.Field{
			Type: graphql.NewNonNull(graphql.ID),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "ID"), nil
			},
		},
		"model": &graphql.Field{
			Type: graphql.NewNonNull(graphql.String),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "Model"), nil
			},
		},
		"batteryLevel": &graphql.Field{
			Type: graphql.NewNonNull(graphql.Int),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "BatteryLevel"), nil
			},
		},
		"rangeKm": &graphql.Field{
			Type: graphql.NewNonNull(graphql.Int),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "RangeKm"), nil
			},
		},
		"totalKm": &graphql.Field{
			Type: graphql.NewNonNull(graphql.Int),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "TotalKm"), nil
			},
		},
		"nextServiceKm": &graphql.Field{
			Type: graphql.NewNonNull(graphql.Int),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "NextServiceKm"), nil
			},
		},
		"tirePressure": &graphql.Field{
			Type: graphql.NewNonNull(graphql.Float),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "TirePressure"), nil
			},
		},
		"softwareVersion": &graphql.Field{
			Type: graphql.NewNonNull(graphql.String),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "SoftwareVersion"), nil
			},
		},
		"isLocked": &graphql.Field{
			Type: graphql.NewNonNull(graphql.Boolean),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "IsLocked"), nil
			},
		},
		"lastUpdated": &graphql.Field{
			Type: graphql.NewNonNull(graphql.String),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "LastUpdated"), nil
			},
		},
	},
})

// userType is the GraphQL object type for User.
var userType = graphql.NewObject(graphql.ObjectConfig{
	Name: "User",
	Fields: graphql.Fields{
		"email": &graphql.Field{
			Type: graphql.NewNonNull(graphql.String),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "Email"), nil
			},
		},
		"name": &graphql.Field{
			Type: graphql.NewNonNull(graphql.String),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "Name"), nil
			},
		},
		"vehicle": &graphql.Field{
			Type: graphql.NewNonNull(vehicleType),
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return resolveField(p.Source, "Vehicle"), nil
			},
		},
	},
})

// NewSchema builds and returns the executable GraphQL schema wired to the given Resolver.
func NewSchema(r *Resolver) (graphql.Schema, error) {
	queryType := graphql.NewObject(graphql.ObjectConfig{
		Name: "Query",
		Fields: graphql.Fields{
			"user": &graphql.Field{
				Type: userType,
				Args: graphql.FieldConfigArgument{
					"email": &graphql.ArgumentConfig{
						Type: graphql.NewNonNull(graphql.String),
					},
				},
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					email, ok := p.Args["email"].(string)
					if !ok || email == "" {
						return nil, fmt.Errorf("email argument is required")
					}
					return r.User(context.Background(), email)
				},
			},
		},
	})

	return graphql.NewSchema(graphql.SchemaConfig{
		Query: queryType,
	})
}
