fig=figure('Name','Robot Controller',...
    'Color',[0.15 0.15 0.15],...
    'MenuBar','none',...
    'ToolBar','none',...
    'NumberTitle','off',...
    'Position',[500,400,250,100],...
    'WindowKeyPressFcn',@keyPressHandler,...
    'WindowKeyReleaseFcn',@keyReleaseHandler);
fig.UserData=struct('allowKeyboard',true,'spacePressed',false,'gPressed',false,...
    'keys',struct('w',false,'a',false,'s',false,'d',false));
armAngle=45;
armUp=false;
auto=false;
baseSpeed=100;
turnAmt=18;
turnSpeed=70;
prevTouch=0;
lastCmd=[0 0];
while isvalid(fig)
    k=fig.UserData.keys; %keys pressed
    f=double(k.w)-double(k.s); %f=1 when w pressed -1 when s pressed
    t=double(k.a)-double(k.d); %t=1 when a pressed -1 when d pressed

    if fig.UserData.gPressed
        fig.UserData.gPressed=false;
        if auto
            auto=false;
            fprintf('KILL SWITCH: autonomous stopped\n');
        else
            auto=true;
        end
        brick.StopMotor('A');
        brick.StopMotor('B');
        lastCmd=[0 0];
        prevTouch=0;
    end

    if fig.UserData.spacePressed
        fig.UserData.spacePressed=false; %doesnt allow space to be pressed more than once
        if armUp
            brick.MoveMotorAngleRel('C',30,-armAngle,'Brake'); %moves motor c with 30 speed 45 degrees down and then stops
        else
            brick.MoveMotorAngleRel('C',30,armAngle,'Brake'); %moves motor c with 30 speed 45 degrees up and then stops
        end
        armUp=~armUp;
    end

    dist=brick.UltrasonicDist(3);
    touch=0;
    if auto
        touch=brick.TouchPressed(1);
        if touch==1&&prevTouch==0
            fprintf('Distance: %5.1f cm | Touch: %d | Decision: TOUCH: BACK UP AND TURN RIGHT\n',dist,touch);
            brick.MoveMotor('A',-baseSpeed);
            brick.MoveMotor('B',-baseSpeed);
            killed=waitOrKill(fig,0.3);
            if ~killed
                brick.MoveMotor('A',-turnSpeed);
                brick.MoveMotor('B',turnSpeed);
                killed=waitOrKill(fig,0.55);
            end
            if killed 
                fig.UserData.gPressed=false;
                auto=false;
                brick.StopMotor('A');
                brick.StopMotor('B');
                cmd=[0 0];
                decision='KILLED';
            else
                cmd=[baseSpeed,baseSpeed];
                decision='TOUCH TURN DONE';
            end
            lastCmd=[0 0];
            touch=brick.TouchPressed(1);
        elseif dist>28
            cmd=[baseSpeed,baseSpeed-turnAmt];
            decision='TURN LEFT';
        elseif dist<18
            cmd=[baseSpeed-turnAmt,baseSpeed];
            decision='TURN RIGHT';
        else
            cmd=[baseSpeed,baseSpeed];
            decision='CONTINUE STRAIGHT';
        end
    else
        decision='MANUAL';
        if f~=0&&t~=0
            if t>0
                cmd=[100*f,40*f]; %move forward to right
            else
                cmd=[40*f,100*f]; %move forward to left
            end
        elseif f~=0
            cmd=[100*f,100*f]; % move forward
        elseif t~=0
            cmd=[70*t,-70*t]; %turn
        else
            cmd=[0 0]; %stop
        end
    end
    prevTouch=touch;
    fprintf('Distance: %5.1f cm | Touch: %d | Decision: %s\n',dist,touch,decision);

    if ~isequal(cmd,lastCmd) %if you are holding same keys nothing happens
        if cmd(1)==0
            brick.StopMotor('A');
            brick.StopMotor('B');
        else
            brick.MoveMotor('A',cmd(1));
            brick.MoveMotor('B',cmd(2));
        end
        lastCmd=cmd;
    end

    drawnow limitrate; %matlab updates window, and gets knew keyboard presses
    pause(0.02);
end

brick.StopMotor('A'); %once the window that is the controller is closed the motors automatically stop
brick.StopMotor('B');
brick.StopMotor('C');

function killed=waitOrKill(fig,secs) 
    killed=false;
    t0=tic;
    while toc(t0)<secs
        drawnow;
        if fig.UserData.gPressed
            killed=true;
            return;
        end
        pause(0.01);
    end
end
function keyPressHandler(src,event) %keypress handler
    if ~src.UserData.allowKeyboard,return;end 
    if strcmp(event.Key,'space') %space moving arm
        src.UserData.spacePressed=true;
    elseif strcmp(event.Key,'g')%kill switch during auto mode
        src.UserData.gPressed=true;
    elseif isfield(src.UserData.keys,event.Key) % w a s d
        src.UserData.keys.(event.Key)=true;
    end
end
function keyReleaseHandler(src,event)
    if ~src.UserData.allowKeyboard,return;end
    if isfield(src.UserData.keys,event.Key) %sets to false when released, tracks keys currently pressed rather than keys sent
        src.UserData.keys.(event.Key)=false;
    end
end