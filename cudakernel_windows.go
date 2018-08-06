// Copyright (c) 2018-2019 The HcashOrg developers.
// +build cuda

package main

import (
	"syscall"
	"unsafe"

	"github.com/barnex/cuda5/cu"
)

var (
	//kernelDll           = syscall.MustLoadDLL("HcashOrg.dll")
	kernelDll               = syscall.MustLoadDLL("HcashOrg.dll")
	precomputeTableProcAddr = kernelDll.MustFindProc("HcashOrg_cpu_setBlock_52").Addr()
	kernelProcAddr          = kernelDll.MustFindProc("HcashOrg_hash_nonce").Addr()
)

func cudaPrecomputeTable(input *[192]byte) {
	syscall.Syscall(precomputeTableProcAddr, 1, uintptr(unsafe.Pointer(input)), 0, 0)
}

func cudaInvokeKernel(gridx, blockx, threads uint32, startNonce uint32, nonceResults cu.DevicePtr, targetHigh uint32) {
	syscall.Syscall6(kernelProcAddr, 6, uintptr(gridx), uintptr(blockx), uintptr(threads),
		uintptr(startNonce), uintptr(nonceResults), uintptr(targetHigh))
}
