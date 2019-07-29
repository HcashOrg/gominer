/**
 * Blake-256 HcashOrg 180-Bytes input Cuda Kernel (Tested on SM 5/5.2/6.1)
 *
 * Tanguy Pruvot - Feb 2016
 *
 * Merged 8-round blake (XVC) tweaks
 * Further improved by: ~2.72%
 * Alexis Provos - Jun 2016
 */

// nvcc  -I. -c HcashOrg.cu --ptx

#include <stdint.h>
#include <memory.h>
#include "miner.h"

#if defined(_WIN32)
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT
#endif /* _WIN32 */

extern "C" {
#include "sph/sph_blake.h"
}

/* threads per block */
#define TPB 640

/* max count of found nonces in one call (like sgminer) */
#define maxResults 4

/* hash by cpu with blake 256 */
extern "C" void HcashOrg_hash(void *output, const void *input)
{
    printf("extern \"C\" void HcashOrg_hash(void *output, const void *input)  1111111111111\n");
	sph_blake256_context ctx;

	sph_blake256_set_rounds(14);

	sph_blake256_init(&ctx);
	sph_blake256(&ctx, input, 180);
	sph_blake256_close(&ctx, output);
}

#include "cuda_helper.h"

#ifdef __INTELLISENSE__
#define __byte_perm(x, y, b) x
#define atomicInc(p, max) (*p)++
#endif

__constant__ uint32_t _ALIGN(16) c_h[2];
__constant__ uint32_t _ALIGN(16) c_data[32];
__constant__ uint32_t _ALIGN(16) c_xors[215];

#define ROR8(a)  __byte_perm(a, 0, 0x0321)
#define ROL16(a) __byte_perm(a, 0, 0x1032)

/* macro bodies */
#define pxorGS(a,b,c,d) { \
	v[a]+= c_xors[i++] + v[b]; \
	v[d] = ROL16(v[d] ^ v[a]); \
	v[c]+= v[d]; \
	v[b] = ROTR32(v[b] ^ v[c], 12); \
	v[a]+= c_xors[i++] + v[b]; \
	v[d] = ROR8(v[d] ^ v[a]); \
	v[c]+= v[d]; \
	v[b] = ROTR32(v[b] ^ v[c], 7); \
}

#define pxorGS2(a,b,c,d, a1,b1,c1,d1) {\
	v[ a]+= c_xors[i++] + v[ b];            v[a1]+= c_xors[i++] + v[b1]; \
	v[ d] = ROL16(v[ d] ^ v[ a]);           v[d1] = ROL16(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 12);      v[b1] = ROTR32(v[b1] ^ v[c1], 12); \
	v[ a]+= c_xors[i++] + v[ b];            v[a1]+= c_xors[i++] + v[b1]; \
	v[ d] = ROR8(v[ d] ^ v[ a]);            v[d1] = ROR8(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 7);       v[b1] = ROTR32(v[b1] ^ v[c1], 7); \
}

#define pxory1GS2(a,b,c,d, a1,b1,c1,d1) { \
	v[ a]+= c_xors[i++] + v[ b];            v[a1]+= c_xors[i++] + v[b1]; \
	v[ d] = ROL16(v[ d] ^ v[ a]);           v[d1] = ROL16(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 12);      v[b1] = ROTR32(v[b1] ^ v[c1], 12); \
	v[ a]+= c_xors[i++] + v[ b];            v[a1]+= (c_xors[i++]^nonce) + v[b1]; \
	v[ d] = ROR8(v[ d] ^ v[ a]);            v[d1] = ROR8(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 7);       v[b1] = ROTR32(v[b1] ^ v[c1], 7); \
}

#define pxory0GS2(a,b,c,d, a1,b1,c1,d1) { \
	v[ a]+= c_xors[i++] + v[ b];            v[a1]+= c_xors[i++] + v[b1]; \
	v[ d] = ROL16(v[ d] ^ v[ a]);           v[d1] = ROL16(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 12);      v[b1] = ROTR32(v[b1] ^ v[c1], 12); \
	v[ a]+= (c_xors[i++]^nonce) + v[ b];    v[a1]+= c_xors[i++] + v[b1]; \
	v[ d] = ROR8(v[ d] ^ v[ a]);            v[d1] = ROR8(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 7);       v[b1] = ROTR32(v[b1] ^ v[c1], 7); \
}

#define pxorx1GS2(a,b,c,d, a1,b1,c1,d1) { \
	v[ a]+= c_xors[i++] + v[ b];            v[a1]+= (c_xors[i++]^nonce) + v[b1]; \
	v[ d] = ROL16(v[ d] ^ v[ a]);           v[d1] = ROL16(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 12);      v[b1] = ROTR32(v[b1] ^ v[c1], 12); \
	v[ a]+= c_xors[i++] + v[ b];            v[a1]+= c_xors[i++] + v[b1]; \
	v[ d] = ROR8(v[ d] ^ v[ a]);            v[d1] = ROR8(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 7);       v[b1] = ROTR32(v[b1] ^ v[c1], 7); \
}

#define pxorx0GS2(a,b,c,d, a1,b1,c1,d1) { \
	v[ a]+= (c_xors[i++]^nonce) + v[ b];    v[a1]+= c_xors[i++] + v[b1]; \
	v[ d] = ROL16(v[ d] ^ v[ a]); 	        v[d1] = ROL16(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 12);      v[b1] = ROTR32(v[b1] ^ v[c1], 12); \
	v[ a]+= c_xors[i++] + v[ b]; 			v[a1]+= c_xors[i++] + v[b1]; \
	v[ d] = ROR8(v[ d] ^ v[ a]); 	        v[d1] = ROR8(v[d1] ^ v[a1]); \
	v[ c]+= v[ d];                          v[c1]+= v[d1]; \
	v[ b] = ROTR32(v[ b] ^ v[ c], 7); 		v[b1] = ROTR32(v[b1] ^ v[c1], 7); \
}

extern "C"
{

//__global__ __launch_bounds__(TPB,1)
__global__ void HcashOrg_gpu_hash_nonce(const uint32_t threads, const uint32_t startNonce, uint32_t *resNonce, const uint32_t highTarget)
{
	const uint32_t thread = blockDim.x * blockIdx.x + threadIdx.x;

	if (thread < threads)
	{
		uint32_t v[16];
		#pragma unroll
		for(int i=0; i<16; i+=4) {
			*(uint4*)&v[i] = *(uint4*)&c_data[i];
		}

		const uint32_t nonce = startNonce + thread;
		v[ 1]+= (nonce ^ 0x13198A2E);
		v[13] = ROR8(v[13] ^ v[1]);
		v[ 9]+= v[13];
		v[ 5] = ROTR32(v[5] ^ v[9], 7);

		int i = 0;
		v[ 1]+= c_xors[i++];// + v[ 6];
		v[ 0]+= v[5];
		v[12] = ROL16(v[12] ^ v[ 1]);         v[15] = ROL16(v[15] ^ v[ 0]);
		v[11]+= v[12];                        v[10]+= v[15];
		v[ 6] = ROTR32(v[ 6] ^ v[11], 12);    v[ 5] = ROTR32(v[5] ^ v[10], 12);
		v[ 1]+= c_xors[i++] + v[ 6];          v[ 0]+= c_xors[i++] + v[ 5];
		v[12] = ROR8(v[12] ^ v[ 1]);          v[15] = ROR8(v[15] ^ v[ 0]);
		v[11]+= v[12];                        v[10]+= v[15];
		v[ 6] = ROTR32(v[ 6] ^ v[11], 7);     v[ 5] = ROTR32(v[ 5] ^ v[10], 7);

		pxorGS2(   2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxory1GS2( 2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxorx1GS2( 0, 5, 10, 15, 1, 6, 11, 12); pxorGS2(   2, 7, 8, 13, 3, 4, 9, 14);
		pxorx1GS2( 0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxorGS2(   2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxorx1GS2( 2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxory1GS2( 2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxorGS2(   2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxory1GS2( 0, 5, 10, 15, 1, 6, 11, 12); pxorGS2(   2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxorx1GS2( 2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxorGS2(   2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxory0GS2( 2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxorGS2(   2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxorx0GS2( 2, 7, 8, 13, 3, 4, 9, 14);
		pxory1GS2( 0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxorGS2(   2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxory1GS2( 2, 7, 8, 13, 3, 4, 9, 14);
		pxorGS2(   0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxorx1GS2( 0, 5, 10, 15, 1, 6, 11, 12); pxorGS2(   2, 7, 8, 13, 3, 4, 9, 14);
		pxorx1GS2( 0, 4, 8, 12, 1, 5, 9, 13); pxorGS2(   2, 6, 10, 14, 3, 7, 11, 15); pxorGS2(   0, 5, 10, 15, 1, 6, 11, 12); pxorGS(    2, 7, 8, 13);

		if ((c_h[1]^v[15]) == v[7]) {
		        uint32_t pos = atomicInc(&resNonce[0], UINT32_MAX)+1;
			resNonce[pos] = nonce;
			return;
		}
	}
}
}

extern "C" {
DLLEXPORT void
HcashOrg_hash_nonce(uint32_t grid, uint32_t block, uint32_t threads,
    uint32_t startNonce, uint32_t *resNonce, uint32_t targetHigh)
{
	HcashOrg_gpu_hash_nonce <<<grid, block>>> (threads, startNonce, resNonce, targetHigh);
}
}

extern "C" {
__host__ DLLEXPORT void
HcashOrg_cpu_setBlock_52(const uint32_t *input, uint32_t updateHeight)
{
/*
    printf("HcashOrg_cpu_setBlock_52  1111111:\n");
	for (int i = 0; i < 244/4; i++)
		printf("%08x", input[i]);
	printf("  \nHcashOrg_cpu_setBlock_52 end 2222222222\n");

    fflush(stdout);

	Precompute everything possible and pass it on constant memory
*/
	const uint32_t z[16] = {
		0x243F6A88U, 0x85A308D3U, 0x13198A2EU, 0x03707344U,
		0xA4093822U, 0x299F31D0U, 0x082EFA98U, 0xEC4E6C89U,
		0x452821E6U, 0x38D01377U, 0xBE5466CFU, 0x34E90C6CU,
		0xC0AC29B7U, 0xC97C50DDU, 0x3F84D5B5U, 0xB5470917U
	};

    uint32_t height = input[128/4];
 //   printf("height = %d, updateHeight = %d\n", height, updateHeight);
	int i=0;
	uint32_t _ALIGN(64) preXOR[215];
	uint32_t _ALIGN(64)   data[16];
	uint32_t _ALIGN(64)      m[16];
	uint32_t _ALIGN(64)      h[ 2];

	sph_blake256_context ctx;
	sph_blake256_set_rounds(14);
	sph_blake256_init(&ctx);
	if(height < updateHeight){
	    sph_blake256(&ctx, input, 128);
	}else{
	    sph_blake256(&ctx, input, 192);
	}


	data[ 0] = ctx.H[0];
	data[ 1] = ctx.H[1];
	data[ 2] = ctx.H[2];
	data[ 3] = ctx.H[3];
	data[ 4] = ctx.H[4];
	data[ 5] = ctx.H[5];
	data[ 8] = ctx.H[6];

#define  BLOCK_OFFSET 16
    if(height < updateHeight){
	    data[12] = swab32(input[35]);
	}else{
	    data[12] = swab32(input[35 + BLOCK_OFFSET]);
	}
	data[13] = ctx.H[7];


	// pre swab32
	if(height < updateHeight){
        m[ 0] = swab32(input[32]);	m[ 1] = swab32(input[33]);
        m[ 2] = swab32(input[34]);	m[ 3] = 0;
        m[ 4] = swab32(input[36]);	m[ 5] = swab32(input[37]);
        m[ 6] = swab32(input[38]);	m[ 7] = swab32(input[39]);
        m[ 8] = swab32(input[40]);	m[ 9] = swab32(input[41]);
        m[10] = swab32(input[42]);	m[11] = swab32(input[43]);
        m[12] = swab32(input[44]);	m[13] = 0x80000001;
	}else{
	    m[ 0] = swab32(input[32 + BLOCK_OFFSET]);	m[ 1] = swab32(input[33 + BLOCK_OFFSET]);
    	m[ 2] = swab32(input[34 + BLOCK_OFFSET]);	m[ 3] = 0;
    	m[ 4] = swab32(input[36 + BLOCK_OFFSET]);	m[ 5] = swab32(input[37 + BLOCK_OFFSET]);
    	m[ 6] = swab32(input[38 + BLOCK_OFFSET]);	m[ 7] = swab32(input[39 + BLOCK_OFFSET]);
    	m[ 8] = swab32(input[40 + BLOCK_OFFSET]);	m[ 9] = swab32(input[41 + BLOCK_OFFSET]);
    	m[10] = swab32(input[42 + BLOCK_OFFSET]);	m[11] = swab32(input[43 + BLOCK_OFFSET]);
    	m[12] = swab32(input[44 + BLOCK_OFFSET]);	m[13] = 0x80000001;
	}
	m[14] = 0;
	if(height < updateHeight){
		m[15] = 0x000005a0;
	}else{
		m[15] = 0x000007a0;
	}
/*
    printf("hash 123456 :\n");
    for (int i = 0; i < 8; i++)
		printf("%08x", ctx.H[i]);
	printf("\nhash 123456 :\n");
    printf("HcashOrg_cpu_setBlock_52  1111111:\n");
	for (int i = 0; i < 16; i++)
		printf("%08x", m[i]);
	printf("  \nHcashOrg_cpu_setBlock_52 end 2222222222\n");
    fflush(stdout);
*/
	h[ 0] = data[ 8];
	h[ 1] = data[13];

	CUDA_SAFE_CALL(cudaMemcpyToSymbol(c_h,h, 8, 0, cudaMemcpyHostToDevice));

	data[ 0]+= (m[ 0] ^ z[1]) + data[ 4];
	data[12]  = SPH_ROTR32(z[4] ^ SPH_C32( height < updateHeight ? 0x5A0: 0x7A0) ^ data[ 0], 16);

	data[ 8] = z[0]+data[12];
	data[ 4] = SPH_ROTR32(data[ 4] ^ data[ 8], 12);
	data[ 0]+= (m[ 1] ^ z[0]) + data[ 4];
	data[12] = SPH_ROTR32(data[12] ^ data[ 0],8);
	data[ 8]+= data[12];
	data[ 4] = SPH_ROTR32(data[ 4] ^ data[ 8], 7);

	data[ 1]+= (m[ 2] ^ z[3]) + data[ 5];
	data[13] = SPH_ROTR32((z[5] ^ SPH_C32(height < updateHeight ? 0x5A0: 0x7A0)) ^ data[ 1], 16);
	data[ 9] = z[1]+data[13];
	data[ 5] = SPH_ROTR32(data[ 5] ^ data[ 9], 12);
	data[ 1]+= data[ 5]; //+nonce ^ ...

	data[ 2]+= (m[ 4] ^ z[5]) + h[ 0];
	data[14] = SPH_ROTR32(z[6] ^ data[ 2],16);
	data[10] = z[2] + data[14];
	data[ 6] = SPH_ROTR32(h[ 0] ^ data[10], 12);
	data[ 2]+= (m[ 5] ^ z[4]) + data[ 6];
	data[14] = SPH_ROTR32(data[14] ^ data[ 2], 8);
	data[10]+= data[14];
	data[ 6] = SPH_ROTR32(data[ 6] ^ data[10], 7);

	data[ 3]+= (m[ 6] ^ z[7]) + h[ 1];
	data[15] = SPH_ROTR32(z[7] ^ data[ 3],16);
	data[11] = z[3] + data[15];
	data[ 7] = SPH_ROTR32(h[ 1] ^ data[11], 12);
	data[ 3]+= (m[ 7] ^ z[6]) + data[ 7];
	data[15] = SPH_ROTR32(data[15] ^ data[ 3],8);
	data[11]+= data[15];
	data[ 7] = SPH_ROTR32(data[11] ^ data[ 7], 7);
	data[ 0]+= m[ 8] ^ z[9];

	CUDA_SAFE_CALL(cudaMemcpyToSymbol(c_data, data, 64, 0, cudaMemcpyHostToDevice));

#define precalcXORGS(x,y) { \
	preXOR[i++]= (m[x] ^ z[y]); \
	preXOR[i++]= (m[y] ^ z[x]); \
}
#define precalcXORGS2(x,y,x1,y1){\
	preXOR[i++] = (m[ x] ^ z[ y]);\
	preXOR[i++] = (m[x1] ^ z[y1]);\
	preXOR[i++] = (m[ y] ^ z[ x]);\
	preXOR[i++] = (m[y1] ^ z[x1]);\
}
	precalcXORGS(10,11);
	preXOR[ 0]+=data[ 6];
	preXOR[i++] = (m[9] ^ z[8]);
	precalcXORGS2(12,13,14,15);
	precalcXORGS2(14,10, 4, 8);
	precalcXORGS2( 9,15,13, 6);
	precalcXORGS2( 1,12, 0, 2);
	precalcXORGS2(11, 7, 5, 3);
	precalcXORGS2(11, 8,12, 0);
	precalcXORGS2( 5, 2,15,13);
	precalcXORGS2(10,14, 3, 6);
	precalcXORGS2( 7, 1, 9, 4);
	precalcXORGS2( 7, 9, 3, 1);
	precalcXORGS2(13,12,11,14);
	precalcXORGS2( 2, 6, 5,10);
	precalcXORGS2( 4, 0,15, 8);
	precalcXORGS2( 9, 0, 5, 7);
	precalcXORGS2( 2, 4,10,15);
	precalcXORGS2(14, 1,11,12);
	precalcXORGS2( 6, 8, 3,13);
	precalcXORGS2( 2,12, 6,10);
	precalcXORGS2( 0,11, 8, 3);
	precalcXORGS2( 4,13, 7, 5);
	precalcXORGS2(15,14, 1, 9);
	precalcXORGS2(12, 5, 1,15);
	precalcXORGS2(14,13, 4,10);
	precalcXORGS2( 0, 7, 6, 3);
	precalcXORGS2( 9, 2, 8,11);
	precalcXORGS2(13,11, 7,14);
	precalcXORGS2(12, 1, 3, 9);
	precalcXORGS2( 5, 0,15, 4);
	precalcXORGS2( 8, 6, 2,10);
	precalcXORGS2( 6,15,14, 9);
	precalcXORGS2(11, 3, 0, 8);
	precalcXORGS2(12, 2,13, 7);
	precalcXORGS2( 1, 4,10, 5);
	precalcXORGS2(10, 2, 8, 4);
	precalcXORGS2( 7, 6, 1, 5);
	precalcXORGS2(15,11, 9,14);
	precalcXORGS2( 3,12,13, 0);
	precalcXORGS2( 0, 1, 2, 3);
	precalcXORGS2( 4, 5, 6, 7);
	precalcXORGS2( 8, 9,10,11);
	precalcXORGS2(12,13,14,15);
	precalcXORGS2(14,10, 4, 8);
	precalcXORGS2( 9,15,13, 6);
	precalcXORGS2( 1,12, 0, 2);
	precalcXORGS2(11, 7, 5, 3);
	precalcXORGS2(11, 8,12, 0);
	precalcXORGS2( 5, 2,15,13);
	precalcXORGS2(10,14, 3, 6);
	precalcXORGS2( 7, 1, 9, 4);
	precalcXORGS2( 7, 9, 3, 1);
	precalcXORGS2(13,12,11,14);
	precalcXORGS2( 2, 6, 5,10);
	precalcXORGS( 4, 0);
	precalcXORGS(15, 8);

	CUDA_SAFE_CALL(cudaMemcpyToSymbol(c_xors, preXOR, 215*sizeof(uint32_t), 0, cudaMemcpyHostToDevice));
}
}

/* ############################################################################################################################### */

