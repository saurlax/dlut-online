type Event = {type:string;data?:unknown;id?:string;error?:string};
type Listener = (event:Event)=>void;

export class RealtimeConnection {
  private socket?:WebSocket;
  private listeners=new Set<Listener>();
  private pending=new Map<string,{resolve:(value:string)=>void;reject:(error:Error)=>void;timer:number}>();
  private stopped=false;
  private ready=false;
  private reconnectTimer=0;
  private attempt=0;
  private sequence=0;
  constructor(private readonly token:string) {}
  subscribe(listener:Listener) {this.listeners.add(listener);return ()=>{this.listeners.delete(listener);};}
  private emit(event:Event) {this.listeners.forEach(listener=>listener(event));}
  start() {this.stopped=false;this.connect();}
  stop() {this.stopped=true;window.clearTimeout(this.reconnectTimer);const socket=this.socket;this.socket=undefined;this.ready=false;socket?.close();this.failPending();}
  private failPending() {for(const item of this.pending.values()){window.clearTimeout(item.timer);item.reject(new Error('连接已断开'));}this.pending.clear();}
  private connect() {
    const socket=new WebSocket(`${location.protocol==='https:'?'wss':'ws'}://${location.host}/api/v1/game/socket`);
    this.socket=socket;
    socket.onopen=()=>socket.send(JSON.stringify({type:'auth',token:this.token}));
    socket.onmessage=message=>{
      if(this.socket!==socket)return;
      const event:Event=JSON.parse(message.data);
      if(event.type==='ready'){this.ready=true;this.attempt=0;this.emit({type:'connected'});return;}
      if(event.type==='result' && event.id) {
        const item=this.pending.get(event.id);if(item){window.clearTimeout(item.timer);this.pending.delete(event.id);if(event.error)item.reject(new Error(event.error));else item.resolve(String(event.data ?? ''));}return;
      }
      this.emit(event);
    };
    socket.onclose=event=>{
      if(this.socket!==socket)return;
      this.ready=false;this.failPending();
      if(this.stopped)return;
      if(event.code===4001){this.emit({type:'auth_error'});return;}
      this.emit({type:'disconnected'});
      const delay=Math.min(1000*2**this.attempt++,15000);
      this.reconnectTimer=window.setTimeout(()=>this.connect(),delay);
    };
  }
  send(type:'chat'|'command',text:string):Promise<string> {
    if(!this.ready || this.socket?.readyState!==WebSocket.OPEN)return Promise.reject(new Error('聊天连接尚未恢复'));
    const id=String(++this.sequence);
    return new Promise((resolve,reject)=>{
      const timer=window.setTimeout(()=>{this.pending.delete(id);reject(new Error('发送结果超时'));},10000);
      this.pending.set(id,{resolve,reject,timer});
      this.socket!.send(JSON.stringify({type,id,text}));
    });
  }
}
