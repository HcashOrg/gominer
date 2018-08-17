CC ?= gcc -fPIC 
CXX ?= g++ -fPIC 
NVCC ?= nvcc -Xcompiler -fPIC 
AR ?= ar

#D:\Program\GOPATH\src\github.com\HcashOrg\gominer\nvidia\CUDA\v7.0\include

# -o is gnu only so this needs to be smarter; it does work because on darwin it
#  fails which is also not windows.
ARCH:=$(shell uname -o)

.DEFAULT_GOAL := build

ifeq ($(ARCH),Msys)
nvidia:
endif

# Windows needs additional setup and since cgo does not support spaces in
# in include and library paths we copy it to the correct location.
#
# Windows build assumes that CUDA V7.0 is installed in its default location.
#
# Windows gominer requires nvml.dll and HcashOrg.dll to reside in the same
# directory as gominer.exe.
ifeq ($(ARCH),Msys)
obj: nvidia
	mkdir nvidia
	cp -r /c/Program\ Files/NVIDIA\ GPU\ Computing\ Toolkit/* nvidia
	cp -r /c/Program\ Files/NVIDIA\ Corporation/NVSMI nvidia
else
obj:
endif
	mkdir obj

ifeq ($(ARCH),Msys)
obj/HcashOrg.dll: obj sph/blake.c HcashOrg.cu
	$(NVCC) --shared --optimize=3 --compiler-options=-GS-,-MD -I. -Isph HcashOrg.cu sph/blake.c -o obj/HcashOrg.dll
else
obj/HcashOrg.a: obj sph/blake.c HcashOrg.cu
	$(NVCC) --lib --optimize=3 -I. HcashOrg.cu sph/blake.c -o obj/HcashOrg.a
endif

ifeq ($(ARCH),Msys)
build: obj/HcashOrg.dll
else
build: obj/HcashOrg.a
endif
	CGO_CFLAGS="-I/c/appsdk/include" CGO_LDFLAGS="-L/c/appsdk/lib/Win32 " go build -tags 'cuda' 
	#go build -tags 'cuda' 

ifeq ($(ARCH),Msys)
install: obj/HcashOrg.dll
else
install: obj/HcashOrg.a
endif
	CGO_CFLAGS="-I/c/appsdk/include" CGO_LDFLAGS="-L/c/appsdk/lib/Win32 " go install -tags 'cuda'
	#go install -tags 'cuda'

clean:
	rm -rf obj
	go clean
ifeq ($(ARCH),Msys)
	rm -rf nvidia
endif
