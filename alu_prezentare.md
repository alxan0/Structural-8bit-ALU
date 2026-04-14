# Prezentare ALU 8-bit structural

## Slide 1 - Titlu
- Structural 8-bit ALU
- Operații: add, subtract, multiply, divide
- Autor: [numele tău]
- Facultate / grupă

## Slide 2 - Scopul proiectului
- Realizarea unei ALU pe 8 biți cu arhitectură structurală
- Reutilizarea modulelor hardware existente
- Separarea clară între control și datapath
- Handshake clar: `start`, `busy`, `done`

## Slide 3 - Arhitectura generală
- Intrări: `A_raw`, `B_raw`, `opcode`, `start`, `clk`, `rst`
- Control central: `control_unit`
- Registre pentru operanzi
- Unități separate pentru fiecare operație
- Rezultat pe 16 biți pentru operațiile care au nevoie de extindere

## Slide 4 - Flux general ALU
- `opcode = 00` -> adunare
- `opcode = 01` -> scădere
- `opcode = 10` -> înmulțire
- `opcode = 11` -> împărțire
- Flux: load operanzi -> execuție -> așteptare finalizare -> `done`

## Slide 5 - Diagrama fluxului ALU
- Inseră diagrama generică ALU
- Arată doar blocurile principale: control, selecția operației, execuție, rezultat

## Slide 6 - Adunare și scădere
- Scăderea este implementată ca adunare în complement față de 2
- `xor_wordgate` inversează operandul la scădere
- `carry_select_adder` produce suma și carry-out
- Se calculează și overflow pentru validarea rezultatului

## Slide 7 - Înmulțitorul Booth Radix-4
- Algoritm signed, în complement față de 2
- Procesează 2 biți ai multiplicatorului pe ciclu
- Doar 4 iterații pentru 8 biți
- Reutilizează adder-ele structurale deja existente

## Slide 8 - Cum funcționează multiplicatorul
- `acc` ține suma parțială
- `x_shift` ține multiplicandul semn-extins și deplasat
- `y_ext` ține multiplicatorul plus bitul de control
- La fiecare pas se decodifică `y_ext[2:0]`
- Se decide: `0`, `+X`, `+2X`, `-X`, `-2X`
- Se actualizează `acc`, apoi se shift-ează `x_shift` și `y_ext`

## Slide 9 - Diagrama fluxului multiplicatorului
- Inseră diagrama Booth Radix-4
- Arată: load -> decode -> add/sub -> shift -> repeat -> done

## Slide 10 - Împărțitorul
- Algoritm secvențial radix-2
- Returnează câtul și restul
- Folosește un flux de control similar cu celelalte unități

## Slide 11 - Verificare
- Testbench-uri pentru operații elementare
- Cazuri directed și random
- Verificare rezultat, `busy`, `done`
- Teste signed pentru înmulțire cu valori negative

## Slide 12 - Concluzii
- ALU structurală completă pe 8 biți
- Arhitectură modulară și reutilizabilă
- Multiplicator signed Booth Radix-4 eficient
- Cod ușor de extins pentru alte operații

## Slide 13 - Întrebări
- Mulțumesc pentru atenție
- Întrebări?




flowchart TD
    A[Start] --> B[start pulse]
    B --> C[Control unit]
    C --> D{opcode}
    D -->|00| E[Add]
    D -->|01| F[Subtract]
    D -->|10| G[Multiply]
    D -->|11| H[Divide]
    E --> I[Load operands]
    F --> I
    G --> I
    H --> I
    I --> J[Execute selected operation]
    J --> K{operation done?}
    K -- no --> J
    K -- yes --> L[Capture result]
    L --> M[done = 1]
    M --> N[Return to idle]