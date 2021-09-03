package com.domwires.ext.service.net;

interface INetServerService extends INetServerServiceImmutable extends IService
{
    function startListen(request:Request):INetServerService;
    function stopListen(request:Request):INetServerService;
    function close(?type:ServerType):INetServerService;
}
