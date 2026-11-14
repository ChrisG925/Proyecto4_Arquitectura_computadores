import csv
from collections import deque
from pathlib import Path
import argparse

WINDOW=64
ENTRY_GAP=4
TRAIL_GAP=15
BUY_Q=16
COOLDOWN=3
CASH0=10000
FEE=5

def load_prices(path):
    with path.open(newline='', encoding='utf-8-sig') as f:
        rows=list(csv.DictReader(f))
    return [int(r['price']) for r in rows]

def simulate(prices, strategy='reversion', save=None):
    cash=CASH0; shares=0; pending=0; orders=0; fees=0; peak=CASH0; maxdd=0
    history=deque(); total=0; high=None; cooldown=0; last_shares=0
    trace=[]
    for tick,price in enumerate(prices):
        # First execute the decision prepared at the previous tick
        action=pending>>6; q=pending&63
        if action==1:
            q=min(q,max(0,(cash-FEE)//price))
            if q>0:
                cash-=q*price+FEE; shares+=q; fees+=FEE; orders+=1
        elif action==2:
            q=min(q,shares)
            if q>0 and cash+q*price>=FEE:
                cash+=q*price-FEE; shares-=q; fees+=FEE; orders+=1
        if last_shares==0 and shares>0:
            high=price
        if last_shares>0 and shares==0:
            high=None; cooldown=COOLDOWN
        last_shares=shares
        wealth=cash+shares*price
        peak=max(peak,wealth); maxdd=max(maxdd,peak-wealth)
        if len(history)==WINDOW: total-=history.popleft()
        history.append(price); total+=price
        if shares>0:
            high=max(high, price)
        pending=0
        if strategy=='reversion' and len(history)==WINDOW:
            if shares>0:
                if WINDOW*price>=total or high-price>=TRAIL_GAP:
                    pending=(2<<6)|min(shares,63)
            elif cooldown==0 and WINDOW*price<=total-WINDOW*ENTRY_GAP and cash>=price+FEE:
                q=min(BUY_Q,63,(cash-FEE)//price)
                if q>0: pending=(1<<6)|q
        if cooldown>0 and shares==0: cooldown-=1
        trace.append((tick,price,f'{action:02b}',q, cash,shares,wealth,f'{pending:02x}'))
    if save:
        with save.open('w',newline='') as f:
            w=csv.writer(f); w.writerow(['tick','precio','accion_ejecutada','cantidad_ejecutada','caja','acciones','patrimonio','decision_siguiente']);w.writerows(trace)
    return dict(wealth=wealth,orders=orders,fees=fees,drawdown=maxdd, trace=trace)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--csv', default='tb/practica.csv')
    parser.add_argument('--ticks',type=int,default=20000)
    args=parser.parse_args()
    prices=load_prices(Path(args.csv))[:args.ticks]
    if not prices:raise SystemExit('No hay precios')
    r=simulate(prices, save=Path('trade_ref_decisiones.csv'))
    buyq=max(0,(CASH0-FEE)//prices[0])
    buyhold=CASH0-(buyq*prices[0]+FEE if buyq else 0)+buyq*prices[-1]
    print(f'Ticks: {len(prices)}')
    print(f'No operar: {CASH0}')
    print(f'Comprar y mantener (referencia del profesor): {buyhold}')
    print(f'Reversión: patrimonio={r["wealth"]}, órdenes={r["orders"]}, comisiones={r["fees"]}, drawdown={r["drawdown"]}')
    print('Decisiones: trade_ref_decisiones.csv')
if __name__=='__main__':main()
