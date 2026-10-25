"""Zusätzliche Geländetexturen: Sand (Wüste), Fels, Waldboden, trockenes Gras, Kies (Gleisbett), Rasen. Nutzt make_textures."""
import sys, numpy as np
sys.argv=[sys.argv[0],'assets/textures']
exec(open('tools/make_textures.py').read().split("\nif __name__")[0].split("\nasphalt()")[0])
def sand():
    h=fnoise(beta=2.6,seed=11)*0.6+band(lo=0.2,hi=0.5,seed=12)*0.25
    ripple=np.sin((np.arange(N)[None,:]*0.08+fnoise(beta=3.2,seed=13)*6))*0.25
    h=h+ripple
    a=col(212,178,128)[None,None,:]*(1+0.06*h[...,None])
    a=a*(1+0.05*band(lo=0.25,hi=0.5,seed=14)[...,None])
    save('sand',a,h,np.full((N,N),0.9),strength=2.5)
def rock():
    h=fnoise(beta=1.6,seed=21)+0.6*fnoise(beta=2.6,seed=22)
    cr=np.abs(band(lo=0.01,hi=0.04,seed=23));h-=np.exp(-cr*6)*1.5
    a=col(128,120,108)[None,None,:]*(1+0.18*np.tanh(h)[...,None])
    a=a*(1+0.12*fnoise(beta=2.2,seed=24)[...,None]*col(1,0.95,0.9))
    save('rock',a,h,np.clip(0.75+0.1*h,0.5,1),strength=6)
def forestfloor():
    h=fnoise(beta=2.0,seed=31)+band(lo=0.15,hi=0.5,seed=32)*0.6
    base=col(72,62,40)[None,None,:];green=col(70,88,40)[None,None,:]
    m=np.clip(0.5+0.4*fnoise(beta=3,seed=33),0,1)[...,None]
    a=base*(1-m)+green*m;a=a*(1+0.15*band(lo=0.2,hi=0.5,seed=34)[...,None])
    save('forest',a,h,np.full((N,N),0.95),strength=3)
def drygrass():
    h=band(lo=0.2,hi=0.5,seed=41)+0.5*fnoise(beta=2.4,seed=42)
    m=np.clip(0.5+0.35*fnoise(beta=3,seed=43),0,1)[...,None]
    a=col(150,140,82)[None,None,:]*(1-m)+col(110,118,60)[None,None,:]*m
    a=a*(1+0.15*h[...,None]*0.5)
    save('drygrass',a,h,np.full((N,N),0.9),strength=2.5)
def gravel():
    h=band(lo=0.12,hi=0.5,seed=51)*0.8+fnoise(beta=2,seed=52)*0.3
    a=col(118,112,104)[None,None,:]*(1+0.25*np.tanh(band(lo=0.15,hi=0.5,seed=53))[...,None])
    save('gravel',a,h,np.full((N,N),0.85),strength=5)
for f in (sand,rock,forestfloor,drygrass,gravel):f();print('ok',f.__name__)
