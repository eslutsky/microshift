// Code generated by lister-gen. DO NOT EDIT.

package v1

import (
	v1 "github.com/openshift/api/config/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/listers"
	"k8s.io/client-go/tools/cache"
)

// ClusterOperatorLister helps list ClusterOperators.
// All objects returned here must be treated as read-only.
type ClusterOperatorLister interface {
	// List lists all ClusterOperators in the indexer.
	// Objects returned here must be treated as read-only.
	List(selector labels.Selector) (ret []*v1.ClusterOperator, err error)
	// Get retrieves the ClusterOperator from the index for a given name.
	// Objects returned here must be treated as read-only.
	Get(name string) (*v1.ClusterOperator, error)
	ClusterOperatorListerExpansion
}

// clusterOperatorLister implements the ClusterOperatorLister interface.
type clusterOperatorLister struct {
	listers.ResourceIndexer[*v1.ClusterOperator]
}

// NewClusterOperatorLister returns a new ClusterOperatorLister.
func NewClusterOperatorLister(indexer cache.Indexer) ClusterOperatorLister {
	return &clusterOperatorLister{listers.New[*v1.ClusterOperator](indexer, v1.Resource("clusteroperator"))}
}
