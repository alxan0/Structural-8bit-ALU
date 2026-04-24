# ALU Structural pe 8 biți

## 1. Domeniu și Definiție Funcțională

Acest document definește arhitectura, interfețele și comportamentul implementării structurale a ALU-ului pe 8 biți din acest repository.

ALU-ul acceptă doi operanzi pe 8 biți (`A_raw`, `B_raw`) și un opcode pe 2 biți, apoi execută una dintre cele patru operații: adunare, scădere, înmulțire sau împărțire. Expune o magistrală unificată de rezultat pe 16 biți, un protocol de sincronizare `start`/`done` și flaguri de stare `carry_out`/`overflow` pentru calea de adunare/scădere.

## 2. Privire de Ansamblu asupra Sistemului

Designul este compus din:
- un modul de integrare la nivel superior: `alu_top`
- un automat de control (FSM): `control_unit`
- trei motoare aritmetice: `adder_substractor`, `booth_radix_4_multiplier`, `radix2_div`
- primitive structurale comune aflate în `src/common`

Secvența de operare la nivel superior:
1. operanzii externi sunt capturați în registrele interne de operanzi
2. automatul de control intră în faza de execuție
3. motorul aritmetic selectat rulează
4. finalizarea motorului este unificată și expusă ca semnal `done` la nivel superior

## 3. Specificația Interfeței Externe

Modul la nivel superior: `src/alu_top.v`

| Semnal | Dir | Lățime | Descriere | Observații |
|---|---|---:|---|---|
| `clk` | in | 1 | ceas de sistem, eșantionat pe frontul crescător | |
| `rst` | in | 1 | reset asincron, activ pe nivel înalt | resetează controlul și toate registrele de stare |
| `start` | in | 1 | cerere de operație; menținut cel puțin un ciclu în starea `IDLE` | un puls de un ciclu este suficient; poate fi menținut ridicat până la `done` |
| `opcode` | in | 2 | selector de operație: `00=add`, `01=sub`, `10=mul`, `11=div` | stabil la momentul asertării |
| `A_raw` | in | 8 | operandul A, reținut în starea `LOAD` | |
| `B_raw` | in | 8 | operandul B, reținut în starea `LOAD` | |
| `result` | out | 16 | magistrala de rezultat | codificarea depinde de opcode |
| `carry_out` | out | 1 | transport ieșire add/sub | semnificativ doar pe calea add/sub |
| `overflow` | out | 1 | depășire cu semn add/sub | semnificativ doar pe calea add/sub |
| `done` | out | 1 | asertat în starea `DONE` a controlerului | deasertat când `start` este eliberat |

### 3.1 Harta opcode-urilor

| opcode | operație | motor | codificarea `result` |
|---|---|---|---|
| `2'b00` | adunare | `adder_substractor` (`sub_mode=0`) | `{8'b0, sum[7:0]}` |
| `2'b01` | scădere | `adder_substractor` (`sub_mode=1`) | `{8'b0, diff[7:0]}` |
| `2'b10` | înmulțire | `booth_radix_4_multiplier` | `product[15:0]` |
| `2'b11` | împărțire | `radix2_div` | `{remainder[7:0], quotient[7:0]}` |

## 4. Arhitectura la Nivel Superior (`alu_top`)

Fișier: `src/alu_top.v`

`alu_top` este responsabil pentru:
- decodificarea opcode-ului și selectarea operației
- capturarea operanzilor prin `register_8bit`
- pornirea execuției pe motorul selectat
- îmbinarea semnalelor busy/done ale motoarelor în unitatea de control
- multiplexarea rezultatelor motoarelor pe o singură magistrală de ieșire

### 4.1 Comportament cheie de integrare

Interfața cu unitatea de control:

```verilog
control_unit brain (
    .clk(clk), .rst(rst), .start(start),
    .exec_done(effective_done),
    .exec_busy(effective_busy),
    .load_en(load_en),
    .exec_start(exec_start),
    .done(done)
);
```

Registrele de operanzi:

```verilog
register_8bit reg_A (.clk(clk), .rst(rst), .load_en(load_en),
                     .data_in(A_raw), .data_out(A_internal));
register_8bit reg_B (.clk(clk), .rst(rst), .load_en(load_en),
                     .data_in(B_raw), .data_out(B_internal));
```

Despachetarea aritmetică:

```verilog
adder_substractor add_sub_unit (
    .start(exec_start), .enable(sel_addsub), .sub_mode(sel_sub),
    .busy(addsub_busy), .done(addsub_done), .result(addsub_result)
);

booth_radix_4_multiplier mul_unit (
    .start(exec_start), .enable(sel_mul),
    .busy(mul_busy), .done(mul_done), .product(mul_result)
);

radix2_div div_unit (
    .start(exec_start & sel_div),
    .ready(div_ready), .done(div_done),
    .quotient(div_quotient), .remainder(div_remainder)
);
```

Multiplexarea rezultatelor (două instanțe structurale `mux2to1` în cascadă):

```verilog
mux2to1 #(.w(16)) mux_result_muldiv (
    .in0(mul_result), .in1({div_remainder, div_quotient}),
    .sel(opcode[0]), .out(result_muldiv));
mux2to1 #(.w(16)) mux_result (
    .in0({8'b0, addsub_result}), .in1(result_muldiv),
    .sel(opcode[1]), .out(result));
```

### 4.2 Protocol unificat de control

`effective_busy` și `effective_done` sunt selectate prin perechi de `mux2to1` controlate de opcode:
- calea add/sub: `addsub_busy`, `addsub_done`
- calea mul: `mul_busy`, `mul_done`
- calea div: `~div_ready`, `div_done`

Aceasta permite unui singur FSM de control să supravegheze toate operațiile fără logică de control specifică fiecărui motor.

## 5. Specificația Unității de Control (`control_unit`)

Fișier: `src/control/control_unit.v`

### 5.1 Codificarea stărilor

| Stare | Codificare |
|---|---|
| `IDLE` | `2'b00` |
| `LOAD` | `2'b01` |
| `EXEC` | `2'b10` |
| `DONE` | `2'b11` |

### 5.2 Logica de tranziție

```verilog
always @(*) begin
    case (state)
        IDLE:    next_state = start     ? LOAD : IDLE;
        LOAD:    next_state = EXEC;
        EXEC:    next_state = exec_done ? DONE : EXEC;
        DONE:    next_state = start     ? DONE : IDLE;
        default: next_state = IDLE;
    endcase
end
```

### 5.3 Tabelul tranzițiilor

| Stare curentă | Condiție | Stare următoare | Intenție |
|---|---|---|---|
| `IDLE` | `start=0` | `IDLE` | așteptare cerere |
| `IDLE` | `start=1` | `LOAD` | capturare operanzi |
| `LOAD` | întotdeauna | `EXEC` | etapă de încărcare pe un singur ciclu |
| `EXEC` | `exec_done=0` | `EXEC` | continuare execuție |
| `EXEC` | `exec_done=1` | `DONE` | operație finalizată |
| `DONE` | `start=1` | `DONE` | menținere completare |
| `DONE` | `start=0` | `IDLE` | eliberare protocol |

### 5.4 Tabelul ieșirilor

| Stare | `load_en` | `exec_start` | `done` |
|---|---:|---:|---:|
| `IDLE` | 0 | 0 | 0 |
| `LOAD` | 1 | 0 | 0 |
| `EXEC` | 0 | `!exec_busy && !exec_done` | 0 |
| `DONE` | 0 | 0 | 1 |

### 5.5 Cerința protocolului de sincronizare

`start` trebuie asertat suficient de mult timp cât controlorul să îl observe în starea `IDLE` — un puls de un ciclu este suficient. Dacă `start` rămâne ridicat după finalizare, `done` rămâne ridicat în starea `DONE` și controlorul rămâne acolo. Deasertarea `start` determină întoarcerea la `IDLE`.

## 6. Specificațiile Componentelor Aritmetice

### 6.1 Adunare/Scădere (`adder_substractor`)

Fișier: `src/arithmetic/adder/adder_substractor.v`

- `sub_mode=0`: calculează `op1 + op2`
- `sub_mode=1`: calculează `op1 + (~op2) + 1` (scădere în complement față de doi)

Implementarea căii de date:

```verilog
xor_wordgate #(.w(8)) gate (.in(op2), .bit_in(sub_mode), .out(op2_xor));
carry_select_adder add  (.op1(op1), .op2(op2_xor), .c_in(sub_mode),
                         .result(adder_result), .c_out(adder_c_out));
assign overflow_raw = (op1[7] == op2_xor[7]) && (adder_result[7] != op1[7]);
```

Ieșiri de stare:
- `c_out`: transportul de ieșire al sumatorului pe 8 biți
- `overflow`: depășire cu semn — activat când ambii operanzi au același MSB dar MSB-ul rezultatului diferă

Comportament de control: necesită `enable=1`; la `start`, rezultatul este înregistrat și se emite un puls `done` de un ciclu.

### 6.2 Înmulțire (`booth_radix_4_multiplier`)

Fișier: `src/arithmetic/multiplier/booth_radix_4_multiplier.v`

Înmulțitor iterativ Booth radix-4 cu semn, 8×8 → ieșire pe 16 biți, 4 iterații de recodificare.

Stare internă: `acc[15:0]`, `x_shift[15:0]`, `y_ext[8:0]`, `count[2:0]`.

Decodificarea Booth pe `y_ext[2:0]`:

| Biți | Acțiune |
|---|---|
| `001`, `010` | `+X` |
| `011` | `+2X` |
| `100` | `-2X` |
| `101`, `110` | `-X` |
| implicit | `0` |

Pasul de acumulare pe 16 biți este construit din două instanțe structurale `carry_select_adder` (octetul inferior și superior), alimentate prin `xor_wordgate` pentru inversare controlată de semn:

```verilog
xor_wordgate #(.w(8)) inv_lo (.in(booth_operand[7:0]),  .bit_in(booth_sub), .out(booth_operand_xor[7:0]));
xor_wordgate #(.w(8)) inv_hi (.in(booth_operand[15:8]), .bit_in(booth_sub), .out(booth_operand_xor[15:8]));
carry_select_adder add_lo (.op1(acc[7:0]),  .op2(booth_operand_xor[7:0]),  .c_in(booth_sub),  .result(add_lo_result), .c_out(add_lo_cout));
carry_select_adder add_hi (.op1(acc[15:8]), .op2(booth_operand_xor[15:8]), .c_in(add_lo_cout), .result(add_hi_result), .c_out(add_hi_cout));
```

FSM-ul modulului: `IDLE` → `CALC` (4 iterații) → `FINISH` (publică produsul, pulsează `done`).

### 6.3 Împărțire (`radix2_div`)

Fișier: `src/arithmetic/division/Radix2.v`

Împărțire restaurativă radix-2 fără semn, lățime parametrizată (implicit `WIDTH=8`), 8 iterații.

Registre: `A` (rest parțial), `M` (împărțitor), `Q` (registru cât), `count`.

Operație per ciclu:
1. deplasarea frontierei între restul parțial `A` și registrul de cât `Q`
2. scăderea împărțitorului prin `carry_select_adder` structural (cu `xor_wordgate` pentru inversare)
3. dacă rezultatul este nenegativ (transport = 1): se acceptă și se setează `Q[0]=1`; altfel se restaurează prin al doilea `carry_select_adder` și se setează `Q[0]=0`

```verilog
xor_wordgate #(.w(WIDTH)) neg_m (.in(M), .bit_in(1'b1), .out(M_inv));
carry_select_adder sub_adder     (.op1(shifted_A), .op2(M_inv), .c_in(1'b1), .result(sub_result),     .c_out(sub_cout));
carry_select_adder restore_adder (.op1(sub_result), .op2(M),    .c_in(1'b0), .result(restore_result), .c_out());
```

La finalizare se produc `quotient` și `remainder`. Stările modulului: `IDLE` → `CALC` (8 cicluri) → înapoi la `IDLE`. Nu este implementată semnalizarea împărțirii la zero.

## 7. Blocuri Structurale Comune

Director: `src/common`

| Modul | Rol |
|---|---|
| `full_adder_cell` | sumatorul complet pe 1 bit — primitiva de bază |
| `ripple_carry_adder` | lanț sumator cu transport în cascadă, parametrizat |
| `adder_level` | etapă de precomputare/selectare cu transport dublu (jumătatea superioară carry-select, 4 biți) |
| `carry_select_adder` | sumator pe 8 biți: ripple pe biții [3:0], `adder_level` pe biții [7:4] |
| `xor_wordgate` | XOR la nivel de cuvânt cu bit de control replicat (`out = in ^ {w{bit_in}}`) |
| `mux2to1` | multiplexor generic parametric 2:1 |
| `register_8bit` | registru sincron de stocare a operanzilor cu reset asincron |

Toate unitățile aritmetice de nivel superior sunt compuse exclusiv din aceste blocuri reutilizabile. Niciun operator aritmetic comportamental nu apare în stratul structural.

## 8. Secvența de Funcționare de Capăt la Capăt

Pentru orice opcode valid, comportamentul la nivel superior este:
1. `start` este asertat cu `A_raw`, `B_raw`, `opcode` stabile
2. controlul intră în starea `LOAD` și reține operanzii în `reg_A`, `reg_B`
3. controlul intră în starea `EXEC` și aplică `exec_start` motorului selectat
4. motorul selectat asertează condiția sa locală de finalizare
5. controlul intră în starea `DONE` și asertează `done` la nivel superior
6. apelantul deasertează `start`, permițând întoarcerea la `IDLE`

## 9. Performanță și Latență

Perioada de ceas: 10 ns (`always #5 clk = ~clk` în testbench).

| Operație | Latență motor (cicluri) | Latență nivel superior (cicluri) | La 10 ns ceas |
|---|---:|---:|---:|
| Adunare (`opcode=00`) | 1 | 4 | 40 ns |
| Scădere (`opcode=01`) | 1 | 4 | 40 ns |
| Înmulțire (`opcode=10`) | 6 | 9 | 90 ns |
| Împărțire (`opcode=11`) | 9 | 12 | 120 ns |

Latența la nivel superior include un ciclu fix de supracap de control: un ciclu `LOAD`, un ciclu de dispatch în `EXEC` și un ciclu `DONE`.

### 9.1 Interpretarea eficienței

- **Adunare/Scădere** este calea cea mai rapidă: calea de date este combinațională; doar protocolul de control adaugă cicluri.
- **Înmulțirea** are latență medie: Booth radix-4 reduce iterațiile produselor parțiale la 4 (jumătate față de Booth radix-2), dar rămâne secvențial.
- **Împărțirea** este calea cea mai lentă: radix-2 restaurativ efectuează o actualizare a unui bit de cât per ciclu și necesită un pas de restaurare pentru scăderile eșuate.

## 10. Rațiunea Alegerii Algoritmilor și Compromisuri

### 10.1 Alegerea algoritmului pentru adunare/scădere

Abordare aleasă: reutilizarea adunării/scăderii în complement față de doi printr-un nucleu `carry_select_adder`.

**Avantaje:**
- o singură cale de date comună suportă atât adunarea cât și scăderea printr-un singur bit `sub_mode`
- carry-select este mai rapid decât ripple pur la lățimea de 8 biți, datorită precomputării paralele a transportului
- flagurile de transport și depășire cu semn sunt generate cu logică minimă suplimentară

**Dezavantaje:**
- carry-select duplică sumatorul jumătății superioare, crescând aria față de un design pur ripple
- compoziție fixă pe 8 biți; nu este parametric la interfața de nivel superior

### 10.2 Alegerea algoritmului pentru înmulțitor

Abordare aleasă: înmulțitor iterativ Booth radix-4 cu semn.

**Avantaje:**
- suport nativ pentru operanzi pe 8 biți cu semn prin recodificare Booth
- 4 iterații pentru intrări de 8 biți (jumătate față de Booth radix-2)
- amprentă hardware moderată față de înmulțitoarele complet paralele

**Dezavantaje:**
- latență multi-ciclu (6 cicluri motor); fără debit pe un singur ciclu
- controlul și calea de date mai complexe decât un simplu înmulțitor shift-add
- mișcare suplimentară a registrului de stare per ciclu

### 10.3 Alegerea algoritmului pentru împărțitor

Abordare aleasă: împărțire restaurativă radix-2 fără semn.

**Avantaje:**
- algoritm simplu și determinist cu mapare structurală directă
- comportament clar per ciclu: registre de cât/rest, număr fix de iterații
- ușor de verificat față de referința `a / b` și `a % b`

**Dezavantaje:**
- latența cea mai mare dintre cele patru operații (9 cicluri motor)
- pasul de restaurare adaugă muncă suplimentară pentru scăderile eșuate
- nicio semnalizare de excepție la împărțirea cu zero

### 10.4 Compromisul arhitectural global

Algoritmii selectați prioritizează consistent **claritatea structurală** și **reutilizarea modulară a blocurilor comune** față de latența minimă sau debitul maxim. Fiecare operație aritmetică din stratul motorului se reduce la instanțe de `carry_select_adder`, `xor_wordgate` și `mux2to1`.

## 11. Verificare

Script de rulare: `run.sh`

| Artefact | Fișier |
|---|---|
| Testbench integrat ALU | `sim/alu_tb.v` |
| Testbench unitate înmulțitor | `src/arithmetic/multiplier/booth_radix_4_multiplier_tb.v` |
| Testbench unitate împărțitor | `src/arithmetic/division/Radix2_tb.v` |

### 11.1 Testbench integrat ALU — `sim/alu_tb.v`

Instanțiază `alu_top` și exercită toate cele patru operații printr-un task `run_op` care aplică intrările, eliberează `start`, așteaptă `done` și compară `result` cu o valoare așteptată precomputată. La nepotrivire, taskul apelează `$fatal` pentru a opri simularea imediat.

| Operație | Cazuri | Cazuri limită notabile |
|---|---:|---|
| Adunare | 8 | operanzi zero, valori maxime, depășire 8 biți |
| Scădere | 7 | operanzi egali, depășire inferioară, `0-1` |
| Înmulțire | 8 | zero, identitate, `255*2` ca semnat (`-1*2 = 0xFFFE`) |
| Împărțire | 9 | deîmpărțit zero, operanzi egali, `1/2`, `255/16`, `100/7` |

Generează `alu_sim.vcd` pentru vizualizarea formelor de undă după simulare.

### 11.2 Testbench unitate înmulțitor — `booth_radix_4_multiplier_tb.v`

Testează `booth_radix_4_multiplier` izolat folosind intrări pe 8 biți cu semn. Taskul `run_case` calculează automat rezultatul așteptat prin aritmetica Verilog cu semn și îl verifică după `done`. Un timeout de 40 de cicluri declanșează `$fatal` dacă modulul se blochează.

- 10 cazuri directe: `0*0`, perechi pozitive, perechi negative, semne mixte, valori extreme (`-128*127`, `127*-128`, `-128*-128`)
- 30 cazuri aleatoare prin `$random` pentru o acoperire largă a domeniului cu semn

Generează `booth_radix_4_multiplier_tb.vcd`.

### 11.3 Testbench unitate împărțitor — `Radix2_tb.v`

Testează `radix2_div` izolat folosind intrări pe 8 biți fără semn. Taskul `run_test` așteaptă `ready`, aplică intrările, pulsează `start`, așteaptă `done`, apoi verifică `quotient` și `remainder` față de operatorii `/` și `%` din Verilog.

14 cazuri incluzând: `100/5`, `50/3`, `255/2`, `128/9`, `0/5` (deîmpărțit zero), `7/7` (operanzi egali), `1/2` (cât zero), `255/255`, `255/1`.

Notă: împărțirea cu zero nu este testată deoarece modulul nu are semnalizare de eroare pentru acest caz.
