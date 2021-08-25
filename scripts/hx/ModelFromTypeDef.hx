package ;

import utils.StringUtils;
import utils.FileUtils;
import hxp.Script;
import sys.FileSystem;
import sys.io.File;

/**
* Generates Domwires compatible models from typedefs.
* Will search for all typedefs marked with @Model metatag and generate class, interfaces and enum.
* See unit test typedeftest.ModelFromTypeDefTest.
* Usage: haxelib run hxp ./scripts/hx/ModelFromTypeDef.hx -Din=<path to input folder>
*
* -Din - path to input directory
* -Doverwrite - overwrite existing files (optional)
* -Dverbose - extended logs (optional)
**/
class ModelFromTypeDef extends Script
{
    private var modelTemplate:String;
    private var iModelTemplate:String;
    private var iModelImmutableTemplate:String;
    private var modelMessageTypeTemplate:String;

    private var getterTemplate:String;
    private var setterTemplate:String;

    private var input:String;
    private var output:String;
    private var overwrite:Bool;
    private var verbose:Bool;

    private var enumValueList:Array<String>;
    private var typedefFile:String;
    private var typeDefFileName:String;
    private var hasErrors:Bool = false;

    public function new()
    {
        super();

        Sys.setCwd(workingDirectory);

        if (!defines.exists("in"))
        {
            trace("Path to input directory is not specified!");
            trace("Define it as flag -Din=path_to_dir...");
            Sys.exit(1);
        }

        input = workingDirectory + defines.get("in");
        overwrite = defines.exists("overwrite");
        verbose = defines.exists("overwrite");

        loadTemplate();
        convertDir(input);
    }

    private function loadTemplate():Void
    {
        modelTemplate = File.getContent("./res/ModelTemplate");
        iModelTemplate = File.getContent("./res/IModelTemplate");
        iModelImmutableTemplate = File.getContent("./res/IModelImmutableTemplate");
        modelMessageTypeTemplate = File.getContent("./res/ModelMessageTypeTemplate");
        getterTemplate = File.getContent("./res/GetterTemplate");
        setterTemplate = File.getContent("./res/SetterTemplate");

        if (verbose)
        {
            traceTemplate("ModelTemplate", modelTemplate);
            traceTemplate("IModelTemplate", iModelTemplate);
            traceTemplate("IModelImmutableTemplate", iModelImmutableTemplate);
            traceTemplate("ModelMessageTypeTemplate", modelMessageTypeTemplate);
            traceTemplate("GetterTemplate", getterTemplate);
            traceTemplate("SetterTemplate", setterTemplate);
        }
    }

    private function traceTemplate(name:String, content:String):Void
    {
        trace(sep() + "-------------- " + name + "--------------");
        trace(sep() + content);
    }

    private function convertDir(path:String):Void
    {
        if (FileSystem.exists(path) && FileSystem.isDirectory(path))
        {
            for (fileName in FileSystem.readDirectory(path))
            {
                var p:String = path + "/" + fileName;
                if (FileSystem.isDirectory(p))
                {
                    convertDir(p);
                } else
                {
                    if (isTypeDef(fileName))
                    {
                        convertFile(p, fileName);
                    }
                }
            }
        }
    }

    private function convertFile(path:String, fileName:String):Void
    {
        typedefFile = File.getContent(path);
        this.typeDefFileName = fileName;

        typedefFile = StringUtils.removeAllEmptySpace(typedefFile);

        if (typedefFile.split("@Model").length > 1)
        {
            output = path.split(fileName)[0];

            trace("Generate model from typedef: " + fileName);

            if (verbose)
            {
                trace(sep() + typedefFile);
            }

            enumValueList = [];

            save(generate(ObjectType.Immutable));
            save(generate(ObjectType.Mutable));
            save(generate(ObjectType.Class));
            save(generate(ObjectType.Enum));
        }
    }

    private function save(result:OutData):Void
    {
        if (hasErrors)
        {
            Sys.exit(1);
        }

        var outputFile:String = output + "/" + result.fileName + ".hx";

        var canSave:Bool = true;

        if (FileSystem.exists(outputFile))
        {
            canSave = overwrite;

            if (!overwrite)
            {
                trace("'" + outputFile + "' already exists. Use -D overwrite to overwrite existing files...");
            }
        }

        if (canSave)
        {
            File.saveContent(outputFile, result.data);

            if (verbose)
            {
                trace("File created: " + outputFile);
                trace(sep() + result.data);
            }
        }
    }

    private function generate(type:EnumValue):OutData
    {
        var template:String = null;

        if (type == ObjectType.Enum)
        {
            template = modelMessageTypeTemplate;
        } else
        if (type == ObjectType.Class)
        {
            template = modelTemplate;
        } else
        if (type == ObjectType.Mutable)
        {
            template = iModelTemplate;
        } else
        if (type == ObjectType.Immutable)
        {
            template = iModelImmutableTemplate;
        }

        var outputFileName:String = null;

        var importSprit:Array<String> = typedefFile.split("import ");
        var semicolonSplit:Array<String> = typedefFile.split(";");
        var equalSplit:Array<String> = typedefFile.split("=");
        var packageSplit:Array<String> = semicolonSplit[0].split("package ");
        var typeDefSplit:Array<String> = semicolonSplit[1].split("typedef ");
        var arrowSplit:Array<String> = typedefFile.split(">");

        if (arrowSplit.length > 2)
        {
            trace("Error: only single inheritance in supported: " + typeDefFileName);
            hasErrors = true;
        }
        if (importSprit.length > 1 && importSprit[0].indexOf("import ") == 0)
        {
            trace("Error: imports are not supported. Use full package path: " + typeDefFileName);
            hasErrors = true;
        }
        if (packageSplit.length != 2)
        {
            trace("Error: package is missing in: " + typeDefFileName);
            hasErrors = true;
        }
        if (typeDefSplit.length != 2)
        {
            trace("Error: typdef is missing in: " + typeDefFileName);
            hasErrors = true;
        }

        var packageValue:String = semicolonSplit[0];
        var packageName:String = packageValue.split(" ")[1];
        var typeDefName:String = typeDefSplit[1].split("=")[0];

        var typeDefNameSplit:Array<String> = typeDefName.split("TypeDef");
        if (typeDefName.split("TypeDef").length != 2 || typeDefName.substr(typeDefName.length - 7) != "TypeDef")
        {
            trace("Error: typdef name should end with 'TypeDef'" + typeDefFileName);
            hasErrors = true;
        }

        var baseModelName:String = null;
        if (arrowSplit.length > 1)
        {
            var baseTypeDef:String = arrowSplit[1].substring(0, arrowSplit[1].indexOf(","));
            var baseTypeDefSplit:Array<String> = baseTypeDef.split("TypeDef");
            if (baseTypeDefSplit.length != 2 || baseTypeDef.substr(baseTypeDef.length - 7) != "TypeDef")
            {
                trace("Error: base typdef name should end with 'TypeDef'" + typeDefFileName);
                hasErrors = true;
            }

            baseModelName = baseTypeDefSplit[0] + "Model";

            trace("Base model: " + baseModelName);
        }

        var modelPrefix:String = typeDefNameSplit[0];
        var modelName:String = modelPrefix + "Model";
        var modelBaseName:String = "AbstractModel";
        var modelBaseInterface:String = "IModel";
        var data:String = modelPrefix.charAt(0).toLowerCase() + modelPrefix.substring(1, modelPrefix.length) + "Data";
        var imports:String = "import com.domwires.core.mvc.model.*;" + sep();
        var _override:String = "";
        var _super:String = "";

        if (baseModelName != null)
        {
            modelBaseName = baseModelName;

            var modelBaseNameSplit:Array<String> = modelBaseName.split(".");
            if (modelBaseNameSplit.length > 1)
            {
                modelBaseNameSplit[modelBaseNameSplit.length - 1] = "I" + modelBaseNameSplit[modelBaseNameSplit.length - 1];

                modelBaseInterface = modelBaseNameSplit.join(".");
            } else
            {
                modelBaseInterface = "I" + modelBaseName;
            }

            _override = "override ";
            _super = "super.init();";
            imports = "";
        }

        if (type == ObjectType.Mutable)
        {
            imports += packageSplit.join("import ") + "." + modelName + ";";
        }

        var out:String = packageValue + ";" + sep(2) + template
            .split("${imports}").join(imports)
            .split("${data}").join(data)
            .split("${_override}").join(_override)
            .split("${_super}").join(_super)
            .split("${model_name}").join(modelName)
            .split("${model_base_name}").join(modelBaseName)
            .split("${typedef_name}").join(typeDefName)
            .split("${model_base_interface}").join(modelBaseInterface);

        var content:String = "";
        var assign:String = "";

        if (type == ObjectType.Enum)
        {
            outputFileName = modelName + "MessageType";

            for (value in enumValueList)
            {
                content += value + sep() + tab();
            }
        }

        var paramList:Array<String> = arrowSplit.length > 1
            ? equalSplit[1].split(",")[1].split(";")
            : equalSplit[1].substring(1, equalSplit[1].lastIndexOf("}")).split(";");

        paramList.pop();

        for (param in paramList)
        {
            if (param.split("final ").length != 2)
            {
                trace("Error: use 'final' to keep immutability: " + param);
                hasErrors = true;
            }
        }

        for (i in 0...paramList.length)
        {
            var line:String = "";

            var param:String = paramList[i];
            var paramTypeSplit:Array<String> = param.split(":");
            var paramFinalSplit:Array<String> = param.split("final ");

            if (paramTypeSplit.length != 2)
            {
                trace("Error: cannot parse type from param: " + param);
                hasErrors = true;
            }

            if (type == ObjectType.Immutable)
            {
                if (outputFileName == null) outputFileName = "I" + modelName + "Immutable";

                line = paramTypeSplit.join("(get, never):").split("final ").join("var ") + ";";
            } else
            if (type == ObjectType.Mutable)
            {
                if (outputFileName == null) outputFileName = "I" + modelName;

                var char:String = paramFinalSplit[1].charAt(0).toUpperCase();
                var methodNameWithType:String = char + paramFinalSplit[1].substring(1, paramFinalSplit[1].length);
                line = param.substring(6, 0) + "set" + methodNameWithType;

                var type:String = line.split(":")[1].split(";").join("");
                var messageType:String = methodNameWithType.split(":")[0];
                enumValueList.push("OnSet" + messageType + ";");

                line = line.split(":").join("(value:" + type + "):").split("):" + type).join("):I" + modelName);
                line = line.split("final ").join("function ") + ";";
            } else
            if (type == ObjectType.Class)
            {
                if (outputFileName == null) outputFileName = modelName;

                var name:String = paramFinalSplit[1].substring(0, paramFinalSplit[1].indexOf(":"));
                var u_name:String = name.charAt(0).toUpperCase() + name.substring(1, name.length);
                var type:String = paramFinalSplit[1].split(":")[1].split(";").join("");
                var messageType:String = "OnSet" + u_name;

                line = getterTemplate.split("${name}").join(name).split("${type}").join(type) + sep(2);
                line += setterTemplate.split("${name}").join(name).split("${u_name}").join(u_name)
                    .split("${type}").join(type).split("${model_name}").join(modelName)
                    .split("${message_type}").join(messageType) + sep(2);

                assign += "_" + name + " = " + data + "." + name + ";" + sep() + tab(2);
            }

            if (type != ObjectType.Enum)
            {
                if (content == "") type != ObjectType.Class ? line += sep() + tab() : "";
                content += line;
            }
        }

        out = out.split("${content}").join(content).split("${assign}").join(assign);

        out = removeEmptyLines(out);

        return {fileName: outputFileName, data: out};
    }

    private function removeEmptyLines(text:String):String
    {
        var formattedText:String = "";
        var lineList:Array<String> = text.split(sep());

        var prevLine:String = null;
        var add:Bool = true;

        for (i in 0...lineList.length)
        {
            var line:String = lineList[i];
            var nextLine:String = i < lineList.length - 1 ? lineList[i + 1] : null;

            if (!StringUtils.isEmpty(line))
            {
                add = true;
            } else
            if (prevLine == null)
            {
                add = true;
            } else
            if (StringUtils.isEmpty(prevLine) || (nextLine.split("}").length == 2))
            {
                add = false;
            }

            if (add)
            {
                formattedText += line + sep();
            }

            prevLine = line;
        }

        return formattedText;
    }

    private function isTypeDef(fileName:String):Bool
    {
        return fileName.substr(fileName.length - 10) == "TypeDef.hx";
    }

    private function sep(x:Int = 1):String
    {
        var out:String = "";

        for (i in 0...x)
        {
            out += FileUtils.lineSeparator();
        }

        return out;
    }

    private function tab(x:Int = 1):String
    {
        var out:String = "";

        for (i in 0...x)
        {
            out += "    ";
        }

        return out;
    }
}

typedef OutData = {
    var fileName:String;
    var data:String;
}

enum ObjectType
{
    Immutable;
    Mutable;
    Class;
    Enum;
}