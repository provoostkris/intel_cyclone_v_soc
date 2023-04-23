### AES
The design is an implementation as specified in the AES documents. As reference the FIPS 197 publication is used.
[FIPS 197](https://nvlpubs.nist.gov/nistpubs/fips/nist.fips.197.pdf)

The code currently supports [vhdl](vhdl/) directory

```
aes_pkg.vhd          : a code package
galois_mul.vhd       : multiplications in galois field
key_expand.vhd       : key expansion for the cypher
sbox.vhd             : normal and inverse substitution
trf_addroundkey.vhd  : cypher transformation 'add round key'
trf_mixcolumns.vhd   : cypher transformation 'mix columns'
trf_shiftrows.vhd    : cypher transformation 'shift rows'
trf_subbytes.vhd     : cypher transformation 'substitute bytes'
```

### dependencies
The code will work stand alone, compile in desired library and use as is.

### User input
*SW(0) is used to reset the design.
