'use client';
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { ArrowRight, BookOpen, CircleHelp, GitBranch, LayoutDashboard, LogOut, Network, Shield, Users, UserRound } from 'lucide-react';
import type { User } from '@supabase/supabase-js';
import { configured, db } from '@/lib/supabase';

type AuthState = { user: User | null; loading: boolean };
const AuthContext = createContext<AuthState>({ user: null, loading: true });
export function AuthProvider({ children }: {children: ReactNode}) {
  const [state, setState] = useState<AuthState>({user:null,loading:true});
  useEffect(() => {
    if (!configured) { setState({user:null,loading:false}); return; }
    db().auth.getUser().then(({data,error}) => setState({user:error ? null : data.user,loading:false}));
    const {data:{subscription}}=db().auth.onAuthStateChange((_event,session)=>setState({user:session?.user ?? null,loading:false}));
    return ()=>subscription.unsubscribe();
  },[]);
  return <AuthContext.Provider value={state}>{children}</AuthContext.Provider>;
}
export const useAuth=()=>useContext(AuthContext);
export function ConfigGate({children}:{children:ReactNode}) {
  const pathname=usePathname();
  if (!configured && pathname!=='/') return <div className="config"><div><span className="eyebrow goldtext">Настройка платформы</span><h1>Подключите Supabase.</h1><p>Для работы школы нужны реальные учётные записи и данные. Добавьте <code>NEXT_PUBLIC_SUPABASE_URL</code> и <code>NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY</code> в окружение проекта, затем перезапустите приложение. Демо-данные и фиктивный вход не используются.</p></div></div>;
  return <>{children}</>;
}
export function Loading() { return <div className="page"><div className="skeleton" style={{width:130}}/><div className="skeleton" style={{width:'55%',height:43}}/><div className="skeleton" style={{width:'100%',height:220,marginTop:40}}/></div>; }
export function Notice({error,onRetry}:{error:string;onRetry?:()=>void}) { return <div role="alert" className="error">{error} {onRetry&&<button className="link-button" onClick={onRetry}>Повторить</button>}</div>; }
const nav=[['/dashboard','Сегодня',LayoutDashboard],['/school','Школа',BookOpen],['/people','Люди',UserRound],['/relationships','Наставничество',GitBranch],['/generations','Поколения',Network],['/groups','Группы',Users],['/admin','Редактор',Shield]] as const;
export function Shell({children,title}:{children:ReactNode;title:string}) {
  const {user,loading}=useAuth(); const router=useRouter(); const pathname=usePathname()||'/';
  useEffect(()=>{if(!loading&&!user)router.replace('/auth?next='+encodeURIComponent(pathname))},[loading,user,router,pathname]);
  if(loading||!user)return <Loading/>;
  return <div className="app-shell">
    <aside className="sidebar"><Link className="brand" href="/dashboard"><span className="brand-mark">S</span><span>SONS OF GOD<span style={{display:'block',fontSize:9,letterSpacing:'.19em',fontWeight:500,color:'#c8d0c2',marginTop:3}}>ШКОЛА УЧЕНИЧЕСТВА</span></span></Link>
      <p className="side-label">ТВОЙ ПУТЬ</p><nav>{nav.map(([href,label,Icon])=><Link key={href} href={href} className={'nav-item '+(pathname===href||pathname.startsWith(href+'/')?'active':'')}><Icon size={17} strokeWidth={1.7}/>{label}</Link>)}</nav>
      <div className="sidebar-bottom"><Link href="/" className="nav-item"><CircleHelp size={17}/>О платформе</Link><button className="nav-item" style={{width:'100%',border:0,background:'none',textAlign:'left'}} onClick={async()=>{await db().auth.signOut();router.push('/')}}><LogOut size={17}/>Выйти</button></div>
    </aside>
    <main className="app-main"><header className="topbar"><span className="breadcrumb">Школа ученичества &nbsp; / &nbsp; <strong>{title}</strong></span><div className="topbar-right"><span>{user.user_metadata?.display_name || user.email}</span><span className="avatar">{(user.user_metadata?.display_name || user.email || 'У').slice(0,1).toUpperCase()}</span></div></header>{children}</main>
  </div>;
}
export function PageHead({eyebrow,title,description,action}:{eyebrow:string;title:string;description?:string;action?:ReactNode}) {return <div className="page-head"><div><div className="eyebrow">{eyebrow}</div><h1>{title}</h1>{description&&<p>{description}</p>}</div>{action}</div>}
export function Modal({title,children,onClose}:{title:string;children:ReactNode;onClose:()=>void}) {return <div className="modal-backdrop" onMouseDown={e=>{if(e.target===e.currentTarget)onClose()}}><div className="modal" role="dialog" aria-modal="true" aria-label={title}><div className="section-row"><h2>{title}</h2><button className="btn small soft" onClick={onClose}>Закрыть</button></div>{children}</div></div>}
export function Empty({title,description,action}:{title:string;description:string;action?:ReactNode}) {return <div className="empty"><span style={{fontSize:28,color:'#a69570'}}>○</span><h3>{title}</h3><p>{description}</p>{action}</div>}
export function Go({href,children,variant='soft'}:{href:string;children:ReactNode;variant?:string}) {return <Link href={href} className={'btn '+variant}>{children}<ArrowRight size={16}/></Link>}
export function Landing() {return <div className="landing"><nav className="land-nav"><Link href="/" className="brand"><span className="brand-mark">S</span> SONS OF GOD</Link><div className="land-links"><a href="#about">Кто такой ученик</a><a href="#path">Как устроен путь</a><Link href="/auth" className="btn small gold">Войти <ArrowRight size={14}/></Link></div></nav>
  <section className="hero"><div className="hero-content"><div className="eyebrow"><span className="eyebrow-rule"/> ШКОЛА УЧЕНИЧЕСТВА SONS OF GOD</div><h1><span>НЕ ПРИХОЖАНИН.</span><span>УЧЕНИК.</span></h1><p className="hero-sub">Школа ученичества Sons of God</p><p className="hero-copy">Иисус призвал нас не просто посещать. Он призвал нас следовать за Ним</p><div className="hero-actions"><Link href="/auth" className="btn gold">Начать путь ученика <ArrowRight size={17}/></Link><a href="#about" className="btn line">Узнать, кто такой ученик</a></div></div><span className="hero-index">01 / ПУТЬ НАЧИНАЕТСЯ ЗДЕСЬ</span><span className="hero-scroll">ЛИСТАЙ ВНИЗ ↓</span></section>
  <section className="land-section manifesto" id="about"><div><div className="eyebrow">НЕ НАЗВАНИЕ. ОБРАЗ ЖИЗНИ.</div><h2>Следовать. Исполнять. Передавать дальше.</h2><p>Ученичество начинается там, где услышанное Слово становится решением, а решение — действием. Не в одиночку: рядом есть люди, которым ты поможешь сделать следующий шаг.</p><Link href="/school" className="btn">Увидеть программу <ArrowRight size={16}/></Link></div><div className="large-number">01<span style={{fontSize:'.21em',verticalAlign:'top',color:'#a89768'}}>→</span></div></section>
  <section className="land-section land-steps" id="path"><span className="eyebrow">ПУТЬ, КОТОРЫЙ ПРОДОЛЖАЕТСЯ</span><h2 className="section-title">Не просто знать.<br/>Жить по-другому.</h2><div className="land-step-grid"><div className="land-step"><span className="num">01 / СЛОВО</span><h3>Слушай и размышляй</h3><p>Короткие уроки помогают увидеть, что говорит Писание — и где оно касается твоей жизни.</p></div><div className="land-step"><span className="num">02 / ДЕЙСТВИЕ</span><h3>Сделай шаг</h3><p>В каждом уроке есть конкретное решение. Назначь дату и вернись с честным результатом.</p></div><div className="land-step"><span className="num">03 / ЛЮДИ</span><h3>Передай дальше</h3><p>Следование за Христом не заканчивается на тебе. Назови человека, с кем разделишь этот путь.</p></div></div></section>
  <section className="land-section quote-section"><span className="eyebrow" style={{color:'#665833'}}>МАТФЕЯ 28:19–20 · СИНОДАЛЬНЫЙ ПЕРЕВОД</span><blockquote>«Итак идите, научите все народы, крестя их во имя Отца и Сына и Святаго Духа, уча их соблюдать все, что Я повелел вам; и се, Я с вами во все дни до скончания века. Аминь»</blockquote><p><a href="https://free.bible/synodal/matthew/28/#v19" target="_blank" rel="noopener noreferrer" className="link-button">Прочитать текст у источника ↗</a></p><p>Призыв Иисуса — не к зрительному залу. К жизни в движении.</p></section>
  <section className="land-section closing"><span className="eyebrow">ТВОЙ СЛЕДУЮЩИЙ ШАГ</span><h2>Путь ученика начинается с одного «да».</h2><p style={{color:'#bfc9bd',marginBottom:30}}>Открой первый урок. Услышь Слово. Сделай шаг.</p><Link href="/auth" className="btn gold">Начать путь ученика <ArrowRight size={17}/></Link></section>
  <footer className="land-footer"><span>SONS OF GOD · ШКОЛА УЧЕНИЧЕСТВА</span><span>Следовать за Ним. Помогать другим следовать.</span></footer></div>}