// Based on https://github.com/openssl/openssl/blob/openssl-3.5.2/crypto/md5/asm/md5-x86_64.pl
// Optimized for the "single block with up to 15 bytes of data" scenario
// Converted to AVX

// Constants
#define W	16	// = 4 * PASSPHRASES
#define X   4	// = PASSPHRASES
#define cns	%rax
#define not	%xmm7

// Arguments
#define pp	%rdi
#define out	%rsi

// Variables
#define a	%xmm0
#define b	%xmm1
#define c	%xmm2
#define d	%xmm3
#define tmp	%xmm4

// VPROLD does not exist until AVX512F
.macro	rotl CL,r32
	vpslld	$\CL,\r32,tmp
	vpsrld	$32-\CL,\r32,\r32
	vpor	tmp,\r32,\r32
.endm

.data
.align	W
constants:
	.rept	X
	.int	0xd76aa477
	.endr
	.rept	X
	.int	0xefcdab89
	.endr
	.rept	X
	.int	0xf8fa0bcc
	.endr
	.rept	X
	.int	0x77777777
	.endr
	.rept	X
	.int	0x98badcfe
	.endr
	.rept	X
	.int	0xbcdb4dd9
	.endr
	.rept	X
	.int	0xb18b7a77
	.endr
	.rept	X
	.int	0xf57c0faf
	.endr
	.rept	X
	.int	0x4787c62a
	.endr
	.rept	X
	.int	0xa8304613
	.endr
	.rept	X
	.int	0xfd469501
	.endr
	.rept	X
	.int	0x698098d8
	.endr
	.rept	X
	.int	0x8b44f7af
	.endr
	.rept	X
	.int	0xffff5bb1
	.endr
	.rept	X
	.int	0x895cd7be
	.endr
	.rept	X
	.int	0x6b901122
	.endr
	.rept	X
	.int	0xfd987193
	.endr
	.rept	X
	.int	0xa679438e
	.endr
	.rept	X
	.int	0x49b40821
	.endr
	.rept	X
	.int	0xf61e2562
	.endr
	.rept	X
	.int	0xc040b340
	.endr
	.rept	X
	.int	0x265e5a51
	.endr
	.rept	X
	.int	0xe9b6c7aa
	.endr
	.rept	X
	.int	0xd62f105d
	.endr
	.rept	X
	.int	0x02441453
	.endr
	.rept	X
	.int	0xd8a1e681
	.endr
	.rept	X
	.int	0xe7d3fbc8
	.endr
	.rept	X
	.int	0x21e1cde6
	.endr
	.rept	X
	.int	0xc33707d6
	.endr
	.rept	X
	.int	0xf4d50d87
	.endr
	.rept	X
	.int	0x455a14ed
	.endr
	.rept	X
	.int	0xa9e3e905
	.endr
	.rept	X
	.int	0xfcefa3f8
	.endr
	.rept	X
	.int	0x676f02d9
	.endr
	.rept	X
	.int	0x8d2a4c8a
	.endr
	.rept	X
	.int	0xfffa3942
	.endr
	.rept	X
	.int	0x8771f681
	.endr
	.rept	X
	.int	0x6d9d6122
	.endr
	.rept	X
	.int	0xfde5380c
	.endr
	.rept	X
	.int	0xa4beea44
	.endr
	.rept	X
	.int	0x4bdecfa9
	.endr
	.rept	X
	.int	0xf6bb4b60
	.endr
	.rept	X
	.int	0xbebfbc70
	.endr
	.rept	X
	.int	0x289b7ec6
	.endr
	.rept	X
	.int	0xeaa127fa
	.endr
	.rept	X
	.int	0xd4ef3085
	.endr
	.rept	X
	.int	0x04881d05
	.endr
	.rept	X
	.int	0xd9d4d039
	.endr
	.rept	X
	.int	0xe6db99e5
	.endr
	.rept	X
	.int	0x1fa27cf8
	.endr
	.rept	X
	.int	0xc4ac5665
	.endr
	.rept	X
	.int	0xf4292244
	.endr
	.rept	X
	.int	0x432aff97
	.endr
	.rept	X
	.int	0xab9423a7
	.endr
	.rept	X
	.int	0xfc93a039
	.endr
	.rept	X
	.int	0x655b59c3
	.endr
	.rept	X
	.int	0x8f0ccc92
	.endr
	.rept	X
	.int	0xffeff47d
	.endr
	.rept	X
	.int	0x85845dd1
	.endr
	.rept	X
	.int	0x6fa87e4f
	.endr
	.rept	X
	.int	0xfe2ce6e0
	.endr
	.rept	X
	.int	0xa3014314
	.endr
	.rept	X
	.int	0x4e0811a1
	.endr
	.rept	X
	.int	0xf7537e82
	.endr
	.rept	X
	.int	0xbd3af235
	.endr
	.rept	X
	.int	0x2ad7d2bb
	.endr
	.rept	X
	.int	0xeb86d391
	.endr
	.rept	X
	.int	0x67452301
	.endr
	.rept	X
	.int	0x10325476
	.endr

.text
.align	W
.globl	computeSeeds
.type	computeSeeds,@function
computeSeeds:
	leaq	constants(%rip),cns
	vpcmpeqd	not,not,not

	# Round 1

	vmovdqa	0*W(pp),a
	vpaddd	0*W(cns),a,a
	rotl	7,a
	vpaddd	1*W(cns),a,a

	vmovdqa	1*W(pp),d
	vpaddd	2*W(cns),d,d
	vpand	3*W(cns),a,tmp
	vpxor	4*W(cns),tmp,tmp
	vpaddd	tmp,d,d
	rotl	12,d
	vpaddd	a,d,d

	vmovdqa	2*W(pp),c
	vpaddd	5*W(cns),c,c
	vpxor	1*W(cns),a,tmp
	vpand	d,tmp,tmp
	vpxor	1*W(cns),tmp,tmp
	vpaddd	tmp,c,c
	rotl	17,c
	vpaddd	d,c,c

	vmovdqa	3*W(pp),b
	vpaddd	6*W(cns),b,b
	vpxor	a,d,tmp
	vpand	c,tmp,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,b,b
	rotl	22,b
	vpaddd	c,b,b

	# 4*W(pp)
	vpaddd	7*W(cns),a,a
	vpxor	d,c,tmp
	vpand	b,tmp,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,a,a
	rotl	7,a
	vpaddd	b,a,a

	# 5*W(pp)
	vpaddd	8*W(cns),d,d
	vpxor	c,b,tmp
	vpand	a,tmp,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,d,d
	rotl	12,d
	vpaddd	a,d,d

	# 6*W(pp)
	vpaddd	9*W(cns),c,c
	vpxor	b,a,tmp
	vpand	d,tmp,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,c,c
	rotl	17,c
	vpaddd	d,c,c

	# 7*W(pp)
	vpaddd	10*W(cns),b,b
	vpxor	a,d,tmp
	vpand	c,tmp,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,b,b
	rotl	22,b
	vpaddd	c,b,b

	# 8*W(pp)
	vpaddd	11*W(cns),a,a
	vpxor	d,c,tmp
	vpand	b,tmp,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,a,a
	rotl	7,a
	vpaddd	b,a,a

	# 9*W(pp)
	vpaddd	12*W(cns),d,d
	vpxor	c,b,tmp
	vpand	a,tmp,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,d,d
	rotl	12,d
	vpaddd	a,d,d

	# 10*W(pp)
	vpaddd	13*W(cns),c,c
	vpxor	b,a,tmp
	vpand	d,tmp,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,c,c
	rotl	17,c
	vpaddd	d,c,c

	# 11*W(pp)
	vpaddd	14*W(cns),b,b
	vpxor	a,d,tmp
	vpand	c,tmp,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,b,b
	rotl	22,b
	vpaddd	c,b,b

	# 12*W(pp)
	vpaddd	15*W(cns),a,a
	vpxor	d,c,tmp
	vpand	b,tmp,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,a,a
	rotl	7,a
	vpaddd	b,a,a

	# 13*W(pp)
	vpaddd	16*W(cns),d,d
	vpxor	c,b,tmp
	vpand	a,tmp,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,d,d
	rotl	12,d
	vpaddd	a,d,d

	vpaddd	14*W(pp),c,c
	vpaddd	17*W(cns),c,c
	vpxor	b,a,tmp
	vpand	d,tmp,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,c,c
	rotl	17,c
	vpaddd	d,c,c

	# 15*W(pp)
	vpaddd	18*W(cns),b,b
	vpxor	a,d,tmp
	vpand	c,tmp,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,b,b
	rotl	22,b
	vpaddd	c,b,b

	# Round 2

	vpaddd	1*W(pp),a,a
	vpaddd	19*W(cns),a,a
	vpandn	c,d,tmp
	vpaddd	tmp,a,a
	vpand	d,b,tmp
	vpaddd	tmp,a,a
	rotl	5,a
	vpaddd	b,a,a

	# 6*W(pp)
	vpaddd	20*W(cns),d,d
	vpandn	b,c,tmp
	vpaddd	tmp,d,d
	vpand	c,a,tmp
	vpaddd	tmp,d,d
	rotl	9,d
	vpaddd	a,d,d

	# 11*W(pp)
	vpaddd	21*W(cns),c,c
	vpandn	a,b,tmp
	vpaddd	tmp,c,c
	vpand	b,d,tmp
	vpaddd	tmp,c,c
	rotl	14,c
	vpaddd	d,c,c

	vpaddd	0*W(pp),b,b
	vpaddd	22*W(cns),b,b
	vpandn	d,a,tmp
	vpaddd	tmp,b,b
	vpand	a,c,tmp
	vpaddd	tmp,b,b
	rotl	20,b
	vpaddd	c,b,b

	# 5*W(pp)
	vpaddd	23*W(cns),a,a
	vpandn	c,d,tmp
	vpaddd	tmp,a,a
	vpand	d,b,tmp
	vpaddd	tmp,a,a
	rotl	5,a
	vpaddd	b,a,a

	# 10*W(pp)
	vpaddd	24*W(cns),d,d
	vpandn	b,c,tmp
	vpaddd	tmp,d,d
	vpand	c,a,tmp
	vpaddd	tmp,d,d
	rotl	9,d
	vpaddd	a,d,d

	# 15*W(pp)
	vpaddd	25*W(cns),c,c
	vpandn	a,b,tmp
	vpaddd	tmp,c,c
	vpand	b,d,tmp
	vpaddd	tmp,c,c
	rotl	14,c
	vpaddd	d,c,c

	# 4*W(pp)
	vpaddd	26*W(cns),b,b
	vpandn	d,a,tmp
	vpaddd	tmp,b,b
	vpand	a,c,tmp
	vpaddd	tmp,b,b
	rotl	20,b
	vpaddd	c,b,b

	# 9*W(pp)
	vpaddd	27*W(cns),a,a
	vpandn	c,d,tmp
	vpaddd	tmp,a,a
	vpand	d,b,tmp
	vpaddd	tmp,a,a
	rotl	5,a
	vpaddd	b,a,a

	vpaddd	14*W(pp),d,d
	vpaddd	28*W(cns),d,d
	vpandn	b,c,tmp
	vpaddd	tmp,d,d
	vpand	c,a,tmp
	vpaddd	tmp,d,d
	rotl	9,d
	vpaddd	a,d,d

	vpaddd	3*W(pp),c,c
	vpaddd	29*W(cns),c,c
	vpandn	a,b,tmp
	vpaddd	tmp,c,c
	vpand	b,d,tmp
	vpaddd	tmp,c,c
	rotl	14,c
	vpaddd	d,c,c

	# 8*W(pp)
	vpaddd	30*W(cns),b,b
	vpandn	d,a,tmp
	vpaddd	tmp,b,b
	vpand	a,c,tmp
	vpaddd	tmp,b,b
	rotl	20,b
	vpaddd	c,b,b

	# 13*W(pp)
	vpaddd	31*W(cns),a,a
	vpandn	c,d,tmp
	vpaddd	tmp,a,a
	vpand	d,b,tmp
	vpaddd	tmp,a,a
	rotl	5,a
	vpaddd	b,a,a

	vpaddd	2*W(pp),d,d
	vpaddd	32*W(cns),d,d
	vpandn	b,c,tmp
	vpaddd	tmp,d,d
	vpand	c,a,tmp
	vpaddd	tmp,d,d
	rotl	9,d
	vpaddd	a,d,d

	# 7*W(pp)
	vpaddd	33*W(cns),c,c
	vpandn	a,b,tmp
	vpaddd	tmp,c,c
	vpand	b,d,tmp
	vpaddd	tmp,c,c
	rotl	14,c
	vpaddd	d,c,c

	# 12*W(pp)
	vpaddd	34*W(cns),b,b
	vpandn	d,a,tmp
	vpaddd	tmp,b,b
	vpand	a,c,tmp
	vpaddd	tmp,b,b
	rotl	20,b
	vpaddd	c,b,b

	# Round 3

	# 5*W(pp)
	vpaddd	35*W(cns),a,a
	vpxor	d,c,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,a,a
	rotl	4,a
	vpaddd	b,a,a

	# 8*W(pp)
	vpaddd	36*W(cns),d,d
	vpxor	c,b,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,d,d
	rotl	11,d
	vpaddd	a,d,d

	# 11*W(pp)
	vpaddd	37*W(cns),c,c
	vpxor	b,a,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,c,c
	rotl	16,c
	vpaddd	d,c,c

	vpaddd	14*W(pp),b,b
	vpaddd	38*W(cns),b,b
	vpxor	a,d,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,b,b
	rotl	23,b
	vpaddd	c,b,b

	vpaddd	1*W(pp),a,a
	vpaddd	39*W(cns),a,a
	vpxor	d,c,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,a,a
	rotl	4,a
	vpaddd	b,a,a

	# 4*W(pp)
	vpaddd	40*W(cns),d,d
	vpxor	c,b,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,d,d
	rotl	11,d
	vpaddd	a,d,d

	# 7*W(pp)
	vpaddd	41*W(cns),c,c
	vpxor	b,a,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,c,c
	rotl	16,c
	vpaddd	d,c,c

	# 10*W(pp)
	vpaddd	42*W(cns),b,b
	vpxor	a,d,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,b,b
	rotl	23,b
	vpaddd	c,b,b

	# 13*W(pp)
	vpaddd	43*W(cns),a,a
	vpxor	d,c,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,a,a
	rotl	4,a
	vpaddd	b,a,a

	vpaddd	0*W(pp),d,d
	vpaddd	44*W(cns),d,d
	vpxor	c,b,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,d,d
	rotl	11,d
	vpaddd	a,d,d

	vpaddd	3*W(pp),c,c
	vpaddd	45*W(cns),c,c
	vpxor	b,a,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,c,c
	rotl	16,c
	vpaddd	d,c,c

	# 6*W(pp)
	vpaddd	46*W(cns),b,b
	vpxor	a,d,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,b,b
	rotl	23,b
	vpaddd	c,b,b

	# 9*W(pp)
	vpaddd	47*W(cns),a,a
	vpxor	d,c,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,a,a
	rotl	4,a
	vpaddd	b,a,a

	# 12*W(pp)
	vpaddd	48*W(cns),d,d
	vpxor	c,b,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,d,d
	rotl	11,d
	vpaddd	a,d,d

	# 15*W(pp)
	vpaddd	49*W(cns),c,c
	vpxor	b,a,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,c,c
	rotl	16,c
	vpaddd	d,c,c

	vpaddd	2*W(pp),b,b
	vpaddd	50*W(cns),b,b
	vpxor	a,d,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,b,b
	rotl	23,b
	vpaddd	c,b,b

	# Round 4

	vpaddd	0*W(pp),a,a
	vpaddd	51*W(cns),a,a
	vpxor	d,not,tmp
	vpor	b,tmp,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,a,a
	rotl	6,a
	vpaddd	b,a,a

	# 7*W(pp)
	vpaddd	52*W(cns),d,d
	vpxor	c,not,tmp
	vpor	a,tmp,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,d,d
	rotl	10,d
	vpaddd	a,d,d

	vpaddd	14*W(pp),c,c
	vpaddd	53*W(cns),c,c
	vpxor	b,not,tmp
	vpor	d,tmp,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,c,c
	rotl	15,c
	vpaddd	d,c,c

	# 5*W(pp)
	vpaddd	54*W(cns),b,b
	vpxor	a,not,tmp
	vpor	c,tmp,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,b,b
	rotl	21,b
	vpaddd	c,b,b

	# 12*W(pp)
	vpaddd	55*W(cns),a,a
	vpxor	d,not,tmp
	vpor	b,tmp,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,a,a
	rotl	6,a
	vpaddd	b,a,a

	vpaddd	3*W(pp),d,d
	vpaddd	56*W(cns),d,d
	vpxor	c,not,tmp
	vpor	a,tmp,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,d,d
	rotl	10,d
	vpaddd	a,d,d

	# 10*W(pp)
	vpaddd	57*W(cns),c,c
	vpxor	b,not,tmp
	vpor	d,tmp,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,c,c
	rotl	15,c
	vpaddd	d,c,c

	vpaddd	1*W(pp),b,b
	vpaddd	58*W(cns),b,b
	vpxor	a,not,tmp
	vpor	c,tmp,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,b,b
	rotl	21,b
	vpaddd	c,b,b

	# 8*W(pp)
	vpaddd	59*W(cns),a,a
	vpxor	d,not,tmp
	vpor	b,tmp,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,a,a
	rotl	6,a
	vpaddd	b,a,a

	# 15*W(pp)
	vpaddd	60*W(cns),d,d
	vpxor	c,not,tmp
	vpor	a,tmp,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,d,d
	rotl	10,d
	vpaddd	a,d,d

	# 6*W(pp)
	vpaddd	61*W(cns),c,c
	vpxor	b,not,tmp
	vpor	d,tmp,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,c,c
	rotl	15,c
	vpaddd	d,c,c

	# 13*W(pp)
	vpaddd	62*W(cns),b,b
	vpxor	a,not,tmp
	vpor	c,tmp,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,b,b
	rotl	21,b
	vpaddd	c,b,b

	vpaddd	4*W(pp),a,a
	vpaddd	63*W(cns),a,a
	vpxor	d,not,tmp
	vpor	b,tmp,tmp
	vpxor	c,tmp,tmp
	vpaddd	tmp,a,a
	rotl	6,a
	vpaddd	b,a,a

	# 11*W(pp)
	vpaddd	64*W(cns),d,d
	vpxor	c,not,tmp
	vpor	a,tmp,tmp
	vpxor	b,tmp,tmp
	vpaddd	tmp,d,d
	rotl	10,d
	vpaddd	a,d,d

	vpaddd	2*W(pp),c,c
	vpaddd	65*W(cns),c,c
	vpxor	b,not,tmp
	vpor	d,tmp,tmp
	vpxor	a,tmp,tmp
	vpaddd	tmp,c,c
	rotl	15,c
	vpaddd	d,c,c

	# 9*W(pp)
	vpaddd	66*W(cns),b,b
	vpxor	a,not,tmp
	vpor	c,tmp,tmp
	vpxor	d,tmp,tmp
	vpaddd	tmp,b,b
	rotl	21,b
	vpaddd	c,b,b

	# Finish

	vpaddd	67*W(cns),a,a
	vpaddd	1*W(cns),b,b
	vpaddd	4*W(cns),c,c
	vpaddd	68*W(cns),d,d
	vpxor	b,a,a
	vpxor	c,a,a
	vpxor	d,a,a
	vmovdqa	a,(out)
	ret
.size	computeSeeds,.-computeSeeds
