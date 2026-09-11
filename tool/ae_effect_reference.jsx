// Synthetic reference project only; never discard an open user project.
(function () {
    if (app.project && (app.project.file || app.project.numItems > 0)) {
        throw new Error('An existing project is open. Reference generation aborted.');
    }
    var root = new File($.fileName).parent.parent;
    var folder = new Folder(root.fsName + '/build/qa/ae-effects');
    folder.create();
    var projectFile = new File(folder.fsName + '/reference.aep');
    if (projectFile.exists) throw new Error('Reference already exists; not overwriting.');
    app.beginSuppressDialogs();
    try {
        var comp = app.project.items.addComp('AUREA_REFERENCE', 256, 128, 1, 1, 24);
        var ramp = comp.layers.addSolid([1, 1, 1], 'Synthetic ramp', 256, 128, 1);
        var gradient = ramp.property('ADBE Effect Parade').addProperty('ADBE Ramp');
        gradient.property(1).setValue([0, 64]);
        gradient.property(2).setValue([0, 0, 0]);
        gradient.property(3).setValue([255, 64]);
        gradient.property(4).setValue([1, 1, 1]);
        var poster = ramp.property('ADBE Effect Parade').addProperty('ADBE Posterize');
        poster.property(1).setValue(4);
        app.project.bitsPerChannel = 8;
        app.project.save(projectFile);
        // Only save the project. Rendering is a separate bounded CLI invocation.
    } finally {
        app.endSuppressDialogs(false);
    }
})();
