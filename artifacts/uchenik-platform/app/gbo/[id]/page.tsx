import { GboPage } from '@/components/gbo-admin';
export default async function Page({params}:{params:Promise<{id:string}>}){const {id}=await params;return <GboPage id={id}/>}