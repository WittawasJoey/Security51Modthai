using System.Reflection;

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: AssemblyInspector <assembly> [name-filter]");
    return 2;
}

var assemblyPath = Path.GetFullPath(args[0]);
var searchDirectory = Path.GetDirectoryName(assemblyPath)!;
var filter = args.Length > 1 ? args[1] : string.Empty;

AppDomain.CurrentDomain.AssemblyResolve += (_, eventArgs) =>
{
    var name = new AssemblyName(eventArgs.Name).Name + ".dll";
    var candidates = new[]
    {
        Path.Combine(searchDirectory, name),
        Path.Combine(searchDirectory, "..", "core", name),
    };
    var candidate = candidates.FirstOrDefault(File.Exists);
    return candidate is null ? null : Assembly.LoadFrom(candidate);
};

var assembly = Assembly.LoadFrom(assemblyPath);
IEnumerable<Type> types;
try
{
    types = assembly.GetTypes();
}
catch (ReflectionTypeLoadException exception)
{
    types = exception.Types.OfType<Type>();
    foreach (var loaderException in exception.LoaderExceptions.Where(item => item is not null))
        Console.Error.WriteLine($"LOAD WARNING: {loaderException!.Message}");
}

foreach (var type in types.Where(type => type.FullName?.Contains(filter, StringComparison.OrdinalIgnoreCase) ?? false))
{
    Console.WriteLine($"TYPE {type.FullName}");
    foreach (var property in type.GetProperties(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance | BindingFlags.DeclaredOnly))
        Console.WriteLine($"  PROPERTY {property.PropertyType.Name} {property.Name} {{ {(property.CanRead ? "get;" : "")} {(property.CanWrite ? "set;" : "")} }}");
    foreach (var field in type.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance | BindingFlags.DeclaredOnly))
        Console.WriteLine($"  FIELD {field.FieldType.Name} {field.Name}");
    foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance | BindingFlags.DeclaredOnly))
    {
        var parameters = string.Join(", ", method.GetParameters().Select(item => $"{item.ParameterType.Name} {item.Name}"));
        Console.WriteLine($"  METHOD {method.ReturnType.Name} {method.Name}({parameters})");
    }
}

return 0;

