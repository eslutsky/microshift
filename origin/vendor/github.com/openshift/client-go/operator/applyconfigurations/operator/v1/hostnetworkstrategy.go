// Code generated by applyconfiguration-gen. DO NOT EDIT.

package v1

import (
	v1 "github.com/openshift/api/operator/v1"
)

// HostNetworkStrategyApplyConfiguration represents an declarative configuration of the HostNetworkStrategy type for use
// with apply.
type HostNetworkStrategyApplyConfiguration struct {
	Protocol  *v1.IngressControllerProtocol `json:"protocol,omitempty"`
	HTTPPort  *int32                        `json:"httpPort,omitempty"`
	HTTPSPort *int32                        `json:"httpsPort,omitempty"`
	StatsPort *int32                        `json:"statsPort,omitempty"`
}

// HostNetworkStrategyApplyConfiguration constructs an declarative configuration of the HostNetworkStrategy type for use with
// apply.
func HostNetworkStrategy() *HostNetworkStrategyApplyConfiguration {
	return &HostNetworkStrategyApplyConfiguration{}
}

// WithProtocol sets the Protocol field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the Protocol field is set to the value of the last call.
func (b *HostNetworkStrategyApplyConfiguration) WithProtocol(value v1.IngressControllerProtocol) *HostNetworkStrategyApplyConfiguration {
	b.Protocol = &value
	return b
}

// WithHTTPPort sets the HTTPPort field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the HTTPPort field is set to the value of the last call.
func (b *HostNetworkStrategyApplyConfiguration) WithHTTPPort(value int32) *HostNetworkStrategyApplyConfiguration {
	b.HTTPPort = &value
	return b
}

// WithHTTPSPort sets the HTTPSPort field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the HTTPSPort field is set to the value of the last call.
func (b *HostNetworkStrategyApplyConfiguration) WithHTTPSPort(value int32) *HostNetworkStrategyApplyConfiguration {
	b.HTTPSPort = &value
	return b
}

// WithStatsPort sets the StatsPort field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the StatsPort field is set to the value of the last call.
func (b *HostNetworkStrategyApplyConfiguration) WithStatsPort(value int32) *HostNetworkStrategyApplyConfiguration {
	b.StatsPort = &value
	return b
}