; ===== Directed hazard test =====

; --- 1. Eight back-to-back LIs into r1. Each LI reads r1's old value, so each depends on the
;        previous one (distance 1). Final r1 = 0008 0007 0006 0005 0004 0003 0002 0001
li   r1, 0, 0x0001
li   r1, 1, 0x0002
li   r1, 2, 0x0003
li   r1, 3, 0x0004
li   r1, 4, 0x0005
li   r1, 5, 0x0006
li   r1, 6, 0x0007
li   r1, 7, 0x0008

; --- 2. Distance 1 on BOTH sources (forward rs1 and rs2 from the same producer)
;        r2 words = doubled words of r1: 0010000E 000C000A 00080006 00040002
au   r2, r1, r1

; --- 3. Double write to the same register, then read it:
;        the reader must see the MOST RECENT write (0x00BB), not 0x00AA
li   r3, 0, 0x00AA
li   r3, 0, 0x00BB
or   r4, r3, r3            ; r4 = 0x...00BB

; --- 4. Distance 2 (served by the register-file write-before-read bypass)
li   r5, 0, 0x0123
li   r5, 1, 0x0456
nop
au   r6, r5, r5            ; r6 word0 = 2 * 0x04560123 = 0x08AC0246

; --- 5. One R4 instruction using three different mechanisms at once:
;        rs1=r10 plain register-file read, rs2=r9 bypass (dist 2), rs3=r8 forwarded (dist 1)
;        r11 word0 = 100 + 6*7 = 142 = 0x8E
li   r10, 0, 100
li   r9,  0, 6
li   r8,  0, 7
simals r11, r10, r9, r8

; --- 6. NOP must never be forwarded: the NOP's rd field is r0, wr_en is 0.
;        r0 is non-zero; the au reads r0 right after three NOPs.
li   r0, 0, 0x7777
nop
nop
nop
au   r13, r0, r0           ; r13 word0 = 0x0000EEEE (NOT 0)

; --- 7. One-source op and immediate op: unused fields must not matter.
;        bcw reads only rs1; mlhcu reads rs1 and a 5-bit immediate (5 here, same as a register just written)
li   r5, 2, 0x0005
bcw  r14, r5
bcw  r5, r1                ; writes r5 (its own source r1 is not in flight)
mlhcu r15, r1, 5           ; imm5 field = 5 = r5, written by the instruction right before it.
                           ; The field is an immediate, so the log must show FORWARD rs2 = 0.

; --- 8. Dependency chain through different formats: au -> ahs -> or (each result is the next input)
au   r16, r1, r2
ahs  r16, r16, r1
or   r18, r16, r16

; --- 9. Saturating multiply-add chain, producer immediately before consumer (rs1 accumulator)
li   r20, 0, 0x7FFF
li   r21, 0, 0x7FFF
li   r22, 0, 0x7FFF
simals r23, r20, r21, r22      ; word0 = 0x7FFF + 0x7FFF*0x7FFF  (no saturation)
simals r23, r23, r21, r22      ; accumulate again (rs1 forwarded)
slmals r24, r23, r23, r23      ; 64-bit lane op reading a just-written register on all three sources
