import 'package:flutter/material.dart';
import '../../core/app_constants.dart';
import '../../state/app_state.dart';
import '../../widgets/feedback.dart';
import '../models/commercial_models.dart';
import '../services/owner_recovery_service.dart';

class StaffAccessScreen extends StatefulWidget {
  const StaffAccessScreen({super.key});
  @override State<StaffAccessScreen> createState()=>_StaffAccessScreenState();
}

class _StaffAccessScreenState extends State<StaffAccessScreen> {
  final name=TextEditingController(), username=TextEditingController(), pin=TextEditingController();
  final recovery=OwnerRecoveryService();
  bool busy=false, obscure=true;

  @override void dispose(){name.dispose();username.dispose();pin.dispose();super.dispose();}

  @override Widget build(BuildContext context){
    final state=AppStateScope.of(context), setup=state.requiresOwnerSetup;
    return Scaffold(
      backgroundColor:const Color(0xFFF2F5FB),
      body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:
        ConstrainedBox(constraints:const BoxConstraints(maxWidth:470),child:Card(child:
          Padding(padding:const EdgeInsets.all(30),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text(AppConstants.appName,textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
            const SizedBox(height:8),
            Text(setup?'Create the owner account. Save the recovery code shown after setup.':'Sign in with your username and PIN.',textAlign:TextAlign.center),
            const SizedBox(height:24),
            if(setup)...[
              TextField(controller:name,decoration:const InputDecoration(labelText:'Owner name',prefixIcon:Icon(Icons.person_outline))),
              const SizedBox(height:12),
            ],
            TextField(controller:username,decoration:const InputDecoration(labelText:'Username',prefixIcon:Icon(Icons.badge_outlined))),
            const SizedBox(height:12),
            TextField(controller:pin,obscureText:obscure,onSubmitted:(_)=>_submit(state),decoration:InputDecoration(
              labelText:setup?'Create PIN':'PIN',prefixIcon:const Icon(Icons.lock_outline),
              suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_outlined:Icons.visibility_off_outlined)),
            )),
            const SizedBox(height:18),
            FilledButton.icon(onPressed:busy?null:()=>_submit(state),icon:const Icon(Icons.login),label:Text(setup?'Create owner account':'Sign in')),
            if(!setup) TextButton.icon(onPressed:busy?null:_forgotPin,icon:const Icon(Icons.key_outlined),label:const Text('Forgot PIN?')),
            const SizedBox(height:8),
            Text(setup?'Recovery codes are stored only as salted hashes.':'Staff PIN: ask an owner/manager to reset it. Owner PIN: use Forgot PIN with your recovery code.',textAlign:TextAlign.center,style:const TextStyle(fontSize:11)),
          ]))))),
      )),
    );
  }

  Future<void> _submit(AppState state) async{
    if(username.text.trim().isEmpty||pin.text.length<4){showFailure(context,'Enter a username and a PIN of at least four characters.');return;}
    if(state.requiresOwnerSetup&&name.text.trim().isEmpty){showFailure(context,'Owner name is required.');return;}
    setState(()=>busy=true);
    try{
      if(state.requiresOwnerSetup){
        await state.createInitialOwner(name:name.text.trim(),username:username.text.trim(),pin:pin.text);
      }else{
        await state.login(username:username.text.trim(),pin:pin.text);
      }
      final user=state.currentUser;
      if(user?.role==StaffRole.owner){
        final code=await recovery.ensureRecoveryCode(user!);
        if(code!=null&&mounted) await _showCode(code,'Save your recovery code','This code can reset the owner PIN if it is forgotten.');
      }
    }catch(e){if(mounted)showFailure(context,e);}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _forgotPin() async{
    final u=TextEditingController(text:username.text.trim()), c=TextEditingController(), n=TextEditingController(), confirm=TextEditingController();
    var working=false;
    try{
      await showDialog<void>(context:context,builder:(dialog)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(
        title:const Text('Recover owner PIN'),
        content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Owners can reset a forgotten PIN with the offline recovery code. Staff should ask an owner or manager to reset their PIN.'),
          const SizedBox(height:12),
          TextField(controller:u,decoration:const InputDecoration(labelText:'Owner username')),
          const SizedBox(height:10),
          TextField(controller:c,decoration:const InputDecoration(labelText:'Recovery code',hintText:'XXXX-XXXX-XXXX-XXXX-XXXX')),
          const SizedBox(height:10),
          TextField(controller:n,obscureText:true,decoration:const InputDecoration(labelText:'New PIN')),
          const SizedBox(height:10),
          TextField(controller:confirm,obscureText:true,decoration:const InputDecoration(labelText:'Confirm new PIN')),
        ])),
        actions:[
          TextButton(onPressed:working?null:()=>Navigator.pop(dialog),child:const Text('Cancel')),
          FilledButton(onPressed:working?null:()async{
            if(n.text.length<4){showFailure(dialog,'The new PIN must contain at least four characters.');return;}
            if(n.text!=confirm.text){showFailure(dialog,'The new PIN values do not match.');return;}
            setLocal(()=>working=true);
            try{
              final next=await recovery.recoverOwnerPin(username:u.text.trim(),recoveryCode:c.text,newPin:n.text);
              if(!dialog.mounted)return;
              Navigator.pop(dialog);
              username.text=u.text.trim(); pin.clear();
              if(mounted)await _showCode(next,'PIN reset successful','Your old recovery code is now invalid. Save this new code.');
            }catch(e){if(dialog.mounted)showFailure(dialog,e);}
            finally{if(dialog.mounted)setLocal(()=>working=false);}
          },child:working?const SizedBox.square(dimension:18,child:CircularProgressIndicator(strokeWidth:2)):const Text('Reset PIN')),
        ],
      )));
    }finally{u.dispose();c.dispose();n.dispose();confirm.dispose();}
  }

  Future<void> _showCode(String code,String title,String message)=>showDialog<void>(
    context:context,barrierDismissible:false,builder:(dialog)=>AlertDialog(
      title:Text(title),
      content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(message),const SizedBox(height:16),
        SelectableText(code,textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
        const SizedBox(height:16),
        const Text('Store it safely outside this computer. Airmonlink cannot display the code again.',textAlign:TextAlign.center),
      ])),
      actions:[FilledButton(onPressed:()=>Navigator.pop(dialog),child:const Text('I saved the code'))],
    ),
  );
}
