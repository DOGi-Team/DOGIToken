# DOGIToken


## 质押合约与解锁
Bonus部分质押，6个月之后开始解锁，每一个月按30天计算，每一个月解锁1/12，
前11个月，每一个月解锁 amount = (bonus - (bonus % 12))/12,
第12个月，解锁bonus-amount。
