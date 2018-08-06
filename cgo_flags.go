// Copyright (c) 2018-2019 The HcashOrg developers.

// +build cuda,!opencl

package main

/*
#cgo !windows LDFLAGS: -L/opt/cuda/lib64 -L/opt/cuda/lib -lcuda -lcudart -lstdc++ obj/HcashOrg.a
#cgo windows LDFLAGS: -Lobj -lHcashOrg -Lnvidia/CUDA/v7.0/lib/x64 -lcuda -lcudart -Lnvidia/NVSMI -lnvml
*/
import "C"
