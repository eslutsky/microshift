package assets

import (
	"context"
	"fmt"
	"time"

	embedded "github.com/openshift/microshift/assets"

	apiextv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	apiextclientv1 "k8s.io/apiextensions-apiserver/pkg/client/clientset/clientset/typed/apiextensions/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	apiruntime "k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	klog "k8s.io/klog/v2"

	"github.com/openshift/library-go/pkg/operator/resource/resourceapply"
	"github.com/openshift/microshift/pkg/config"

	apiregistrationv1 "k8s.io/kube-aggregator/pkg/apis/apiregistration/v1"
	apiregistrationv1client "k8s.io/kube-aggregator/pkg/client/clientset_generated/clientset/typed/apiregistration/v1"
)

const (
	customResourceReadyInterval = 5 * time.Second
	customResourceReadyTimeout  = 10 * time.Minute
)

var (
	apiExtensionsScheme = apiruntime.NewScheme()
	apiExtensionsCodecs = serializer.NewCodecFactory(apiExtensionsScheme)
	crds                = []string{
		"crd/0000_03_config-operator_02_rangeallocations.crd.yaml",
		"crd/0000_03_config-operator_01_securitycontextconstraints.crd.yaml",
		"crd/route.crd.yaml",
		"crd/storage_version_migration.crd.yaml",
		"components/lvms/topolvm.io_logicalvolumes.yaml",
		"components/csi-snapshot-controller/volumesnapshotclasses.yaml",
		"components/csi-snapshot-controller/volumesnapshotcontents.yaml",
		"components/csi-snapshot-controller/volumesnapshots.yaml",
	}
	// for apis that belong to a group served by openshift-apiserver but are themselves served
	// as a CR, the crd registration controller will not automatically create local apiservices
	localAPIServices = []string{
		"core/securityv1-local-apiservice.yaml",
	}
)

func init() {
	if err := apiextv1.AddToScheme(apiExtensionsScheme); err != nil {
		panic(err)
	}
}

func isEstablished(ctx context.Context, cs *apiextclientv1.ApiextensionsV1Client, obj apiruntime.Object) (bool, error) {
	var err error
	switch crd := obj.(type) {
	case *apiextv1.CustomResourceDefinition:
		if crd, err = cs.CustomResourceDefinitions().Get(ctx, crd.Name, metav1.GetOptions{}); err == nil {
			for _, condition := range crd.Status.Conditions {
				if condition.Type == apiextv1.Established && condition.Status == apiextv1.ConditionTrue {
					return true, nil
				}
			}
		}
	default:
		panic(fmt.Errorf("unknown type: %T", obj))
	}
	// returns nil error if CRD does not have condition Established == True or a non-nil error
	return false, err
}

func WaitForCrdsEstablished(ctx context.Context, cfg *config.Config) error {
	restConfig, err := clientcmd.BuildConfigFromFlags("", cfg.KubeConfigPath(config.KubeAdmin))
	if err != nil {
		return err
	}

	clientSet := apiextclientv1.NewForConfigOrDie(restConfig)
	for _, crd := range crds {
		klog.Infof("Waiting for crd %s condition.type: established", crd)
		var crdBytes []byte
		crdBytes, err = embedded.Asset(crd)
		if err != nil {
			return fmt.Errorf("error getting asset %s: %v", crd, err)
		}
		obj := readCRDOrDie(crdBytes)

		if err = wait.PollUntilContextTimeout(ctx, customResourceReadyInterval, customResourceReadyTimeout, true, func(ctx context.Context) (done bool, err error) {
			done, e := isEstablished(ctx, clientSet, obj)
			// Intermittent errors can occur when calling the apiserver.  To be on the safe side, log them, but poll until timeout
			if e != nil {
				klog.Errorf("polling for crd condition status \"established\"=\"true\": %v", e)
			}
			return done, nil
		}); err != nil {
			// This will contain only errors generated by wait.PollImmediate (i.e. a timeout error).
			return fmt.Errorf("waiting for default CRD: %v", err)
		}
	}
	return nil
}

func readCRDOrDie(objBytes []byte) *apiextv1.CustomResourceDefinition {
	var crd apiextv1.CustomResourceDefinition
	err := apiruntime.DecodeInto(apiExtensionsCodecs.UniversalDecoder(apiextv1.SchemeGroupVersion), objBytes, &crd)
	if err != nil {
		panic(err)
	}
	return &crd
}

func applyCRD(ctx context.Context, client *apiextclientv1.ApiextensionsV1Client, crd *apiextv1.CustomResourceDefinition) error {
	_, _, err := resourceapply.ApplyCustomResourceDefinitionV1(ctx, client, assetsEventRecorder, crd)
	return err
}

func ApplyCRDs(ctx context.Context, cfg *config.Config) error {
	lock.Lock()
	defer lock.Unlock()

	restConfig, err := clientcmd.BuildConfigFromFlags("", cfg.KubeConfigPath(config.KubeAdmin))
	if err != nil {
		return err
	}
	rest.AddUserAgent(restConfig, "crd-agent")

	apiRegistrationClient, err := apiregistrationv1client.NewForConfig(restConfig)
	if err != nil {
		return err
	}

	apiRegistrationScheme := apiruntime.NewScheme()
	apiRegistrationCodecs := serializer.NewCodecFactory(apiRegistrationScheme)

	for _, apiServiceManifest := range localAPIServices {
		apiServiceBytes, err := embedded.Asset(apiServiceManifest)
		if err != nil {
			return err
		}
		var apiService apiregistrationv1.APIService
		err = apiruntime.DecodeInto(apiRegistrationCodecs.UniversalDecoder(apiregistrationv1.SchemeGroupVersion), apiServiceBytes, &apiService)
		if err != nil {
			return err
		}
		_, _, err = resourceapply.ApplyAPIService(ctx, apiRegistrationClient, assetsEventRecorder, &apiService)
		if err != nil {
			return err
		}
	}

	client := apiextclientv1.NewForConfigOrDie(restConfig)

	for _, crd := range crds {
		klog.Infof("Applying openshift CRD %s", crd)
		crdBytes, err := embedded.Asset(crd)
		if err != nil {
			return fmt.Errorf("error getting asset %s: %v", crd, err)
		}
		c := readCRDOrDie(crdBytes)
		if err = wait.PollUntilContextTimeout(ctx, customResourceReadyInterval, customResourceReadyTimeout, true, func(ctx context.Context) (done bool, err error) {
			if err := applyCRD(ctx, client, c); err != nil {
				klog.Warningf("failed to apply openshift CRD %s: %v", crd, err)
				return false, nil
			}
			klog.Infof("Applied openshift CRD %s", crd)
			return true, nil
		}); err != nil {
			if err == context.DeadlineExceeded {
				return fmt.Errorf("%v during syncCustomResourceDefinitions", err)
			}
			return err
		}
	}

	return nil
}
