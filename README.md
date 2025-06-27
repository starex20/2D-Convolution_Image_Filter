# 2D-Convolution Image Filter

![image](https://github.com/user-attachments/assets/21653713-639b-4ae5-8b52-274a786d544f)


<br/><br/>

# 구현 내용

### grayscale BMP format
![image](https://github.com/user-attachments/assets/02668b6d-bc63-458f-8b3a-5a6582b842ce)



<br/><br/>

## Block Diagram
![image](https://github.com/user-attachments/assets/9a6c7ce4-513b-411e-a72e-c1a00f4ec2d8)
<br/>
![image](https://github.com/user-attachments/assets/14ddcb70-12d8-4732-85e7-49207e88a65e)

<br/><br/>

## Register Map

| Address       | Register Name | Access Type | Register Description    |
|-------------|------|--------|---------|
| 0x00  | CONTROL    | R/W   | Bit 0 : start    |
| 0x04  | STATUS    | R      | Bit 1-0 : status (IDLE, RUN, DONE)  |
| 0x08  | FILTER    |  R/W     | Bit 2-0 : Weight1 <br/> Bit 5-3 : Weight2 <br/>       ⋮ <br/> Bit 26-24 : Weight9 |

<br/><br/>

# Result
![image](https://github.com/user-attachments/assets/b197d097-a43c-49d2-81d0-d196fda0c263)



